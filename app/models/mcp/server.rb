module Mcp
  # A single MCP server definition, in the shape Claude Code stores it.
  #
  # Stdio servers carry a command plus arguments and environment; http and sse
  # servers carry a URL plus headers. Unrecognised keys are round-tripped in
  # +extras+ so editing a server never silently drops fields this app does not
  # know about.
  class Server
    include ActiveModel::Model
    include ActiveModel::Attributes

    NAME_FORMAT = /\A[a-zA-Z0-9][a-zA-Z0-9_.-]*\z/
    REMOTE_TRANSPORTS = %w[http sse].freeze
    TRANSPORTS = %w[stdio http sse].freeze

    # Environment names that usually hold something you would rather not have
    # sitting in a config file in the clear.
    SECRET_NAME = /token|secret|key|password|passwd|credential/i

    # A shell-style reference, which is the safe way to write the above.
    VARIABLE_REFERENCE = /\A\$\{?\w+\}?\z/

    URL_LIKE = %r{\Ahttps?://}i

    attribute :command, :string
    attribute :name, :string
    attribute :transport, :string, default: 'stdio'
    attribute :url, :string

    attr_accessor :args, :env, :extras, :headers, :project_path
    attr_writer :scope

    validates :name, format: { message: 'may only contain letters, numbers, dashes, dots and underscores',
                               with: NAME_FORMAT },
                     presence: true
    validates :transport, inclusion: { in: TRANSPORTS }
    validates :command, presence: true, if: :stdio?
    validates :url, presence: true, if: :remote?
    validate :url_is_http

    # Builds a server from the raw JSON hash keyed by server name.
    def self.from_config(name, config, scope: nil, project_path: nil)
      config = {} unless config.is_a?(Hash)
      known = %w[args command env headers type url]

      new(
        args: Array(config['args']).map(&:to_s),
        command: config['command'],
        env: stringify(config['env']),
        extras: config.except(*known),
        headers: stringify(config['headers']),
        name: name,
        project_path: project_path,
        scope: scope,
        transport: config['type'].presence || (config['url'].present? ? 'http' : 'stdio'),
        url: config['url']
      )
    end

    def self.stringify(value)
      return {} unless value.is_a?(Hash)

      value.transform_keys(&:to_s).transform_values(&:to_s)
    end

    def initialize(attributes = {})
      attributes = attributes.symbolize_keys
      @args = Array(attributes.delete(:args)).map(&:to_s)
      @env = self.class.stringify(attributes.delete(:env))
      @extras = attributes.delete(:extras) || {}
      @headers = self.class.stringify(attributes.delete(:headers))
      @project_path = attributes.delete(:project_path)
      @scope = attributes.delete(:scope)

      super(attributes)
    end

    # Identity used to decide whether two definitions of the same name are the
    # same server or a genuine conflict.
    def fingerprint
      Digest::SHA256.hexdigest(JSON.generate(to_config))
    end

    def local?
      scope == Scope.local
    end

    def persisted?
      false
    end

    def remote?
      REMOTE_TRANSPORTS.include?(transport)
    end

    def scope
      return @scope if @scope.blank? || @scope.is_a?(Scope)

      Scope.fetch(@scope)
    end

    def stdio?
      transport == 'stdio'
    end

    def summary
      return url.to_s if remote?

      [command, *args].compact_blank.join(' ')
    end

    def to_config
      config = extras.deep_dup
      config['type'] = transport

      if remote?
        config['url'] = url
        config['headers'] = headers if headers.present?
      else
        config['command'] = command
        config['args'] = args if args.present?
        config['env'] = env if env.present?
      end

      config.sort.to_h
    end

    def to_param
      name
    end

    # Structurally valid, but suspicious. See Mcp::Warning.
    def warnings
      [url_as_command_warning, ignored_field_warning, *literal_credential_warnings].compact
    end

    private

    # env is handed to a child process and headers are sent with an HTTP
    # request, so each is silently dropped by the other transport.
    def ignored_field_warning
      if stdio? && headers.present?
        return Warning.new(
          code: :ignored_headers,
          field: :headers,
          message: 'Headers are only sent by http and sse servers.',
          suggestion: 'They are ignored for a stdio server.'
        )
      end

      return nil unless remote? && env.present?

      Warning.new(
        code: :ignored_env,
        field: :env,
        message: 'Environment variables are only passed to stdio servers.',
        suggestion: 'Send credentials as headers instead.'
      )
    end

    def literal_credential_warnings
      env.filter_map do |key, value|
        next unless key.match?(SECRET_NAME)
        next if value.blank? || value.match?(VARIABLE_REFERENCE)

        Warning.new(
          code: :literal_credential,
          field: :env,
          message: "#{key} holds a literal value.",
          suggestion: "Use ${#{key}} to read it from the environment instead of storing it here."
        )
      end
    end

    # A stdio server execs its command. A URL there fails at launch, and almost
    # always means the transport is wrong rather than the command.
    def url_as_command_warning
      return nil unless stdio?
      return nil unless command.to_s.match?(URL_LIKE)

      Warning.new(
        code: :url_as_command,
        field: :command,
        message: 'This is a stdio server, but its command is a URL, so it cannot start.',
        suggestion: "Change the transport to http and move #{command} into the URL field."
      )
    end

    def url_is_http
      return if url.blank?
      return if url.match?(URL_LIKE)

      errors.add(:url, 'must start with http:// or https://')
    end
  end
end
