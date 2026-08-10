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

    private

    def url_is_http
      return if url.blank?
      return if url.match?(%r{\Ahttps?://}i)

      errors.add(:url, 'must start with http:// or https://')
    end
  end
end
