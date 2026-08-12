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

    # Header names that carry the same risk. Authorization and Cookie do not read
    # as secrets by name, but their values almost always are.
    SECRET_HEADER_NAME = Regexp.union(/\A(?:proxy-)?authorization\z/i, /\Acookie\z/i, SECRET_NAME)

    # A shell-style reference, which is the safe way to write the above. Either
    # $NAME or ${NAME}, the braced form optionally carrying the :-default,
    # :+alternate or :?message suffix Claude Code expands. Unanchored on purpose:
    # a reference embedded in a larger value, as in "Bearer ${TOKEN}", still
    # means the credential itself is not sitting in the file.
    VARIABLE_NAME = /[A-Za-z_][A-Za-z0-9_]*/
    VARIABLE_REFERENCE = /\$\{#{VARIABLE_NAME}(?::[-+?][^{}]*)?\}|\$#{VARIABLE_NAME}/

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

      super
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
      config = extras.deep_dup.merge('type' => transport)
      config.merge!(remote? ? remote_config : stdio_config)

      config.sort.to_h
    end

    def to_param
      name
    end

    # Structurally valid, but suspicious. See Mcp::Warning.
    def warnings
      [
        url_as_command_warning,
        ignored_field_warning,
        *malformed_reference_warnings,
        *literal_credential_warnings
      ].compact
    end

    private

    # The pairs whose name suggests the value is a credential.
    def credential_pairs
      pairs.select do |field, key, _value|
        field == :headers ? key.match?(SECRET_HEADER_NAME) : key.match?(SECRET_NAME)
      end
    end

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

    # env values reach a stdio child process and header values are sent with every
    # http request, so both are places a credential ends up stored in the clear.
    def literal_credential_warnings
      credential_pairs.filter_map do |field, key, value|
        next if value.blank? || value.match?(VARIABLE_REFERENCE)
        next if malformed_reference?(value)

        Warning.new(
          code: :literal_credential,
          field: field,
          message: "#{key} holds a literal value.",
          suggestion: "Use ${#{variable_name_for(key)}} to read it from the environment instead of storing it here."
        )
      end
    end

    # A reference that started but never finished, such as ${FOO. Claude Code
    # leaves it in place, so the child process is handed the braces verbatim.
    def malformed_reference?(value)
      value.gsub(VARIABLE_REFERENCE, '').include?('${')
    end

    def malformed_reference_warnings
      pairs.filter_map do |field, key, value|
        next unless malformed_reference?(value)

        Warning.new(
          code: :malformed_variable_reference,
          field: field,
          message: "#{key} has an unfinished ${…} reference.",
          suggestion: 'Close the brace, or the value is passed through exactly as written.'
        )
      end
    end

    # Every env and header pair, tagged with the field it came from so a warning
    # can point at the right part of the form.
    def pairs
      env.map { |key, value| [:env, key, value] } + headers.map { |key, value| [:headers, key, value] }
    end

    def remote_config
      config = { 'url' => url }
      config['headers'] = headers if headers.present?

      config
    end

    def stdio_config
      config = { 'command' => command }
      config['args'] = args if args.present?
      config['env'] = env if env.present?

      config
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

    # An env or header name turned into something legal to write inside ${}, so
    # the suggested fix can be pasted straight into the field. Header names carry
    # dashes that an environment variable cannot.
    def variable_name_for(key)
      key.to_s.gsub(/[^A-Za-z0-9_]/, '_').upcase
    end
  end
end
