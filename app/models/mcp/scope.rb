module Mcp
  # The three places Claude Code looks for MCP server definitions.
  #
  # When the same server name appears in more than one of them the highest
  # precedence wins, which is what makes overlaps worth surfacing.
  class Scope
    # %<config>s is filled in from the configured user config path rather than
    # written out, so pointing MCP_CONFIG_USER_FILE somewhere else does not leave
    # the interface describing a file it is not editing.
    DEFINITIONS = {
      'user' => {
        accent: 'indigo',
        description: 'Available in every project on this machine.',
        location: '%<config>s → mcpServers',
        name: 'User',
        precedence: 1,
        project_specific: false
      },
      'project' => {
        accent: 'emerald',
        description: 'Checked into the repository and shared with the team.',
        location: "<project>/#{ProjectConfig::FILENAME} → mcpServers",
        name: 'Project',
        precedence: 2,
        project_specific: true
      },
      'local' => {
        accent: 'amber',
        description: 'Private to you, stored per project path in %<config>s.',
        location: '%<config>s → projects[path].mcpServers',
        name: 'Local',
        precedence: 3,
        project_specific: true
      }
    }.freeze

    KEYS = DEFINITIONS.keys.freeze

    def self.all
      @all ||= KEYS.map { |key| new(key) }
    end

    def self.exists?(key)
      KEYS.include?(key.to_s)
    end

    def self.fetch(key)
      all.find { |scope| scope.key == key.to_s } ||
        raise(ArgumentError, "unknown MCP scope: #{key.inspect}")
    end

    def self.local
      fetch('local')
    end

    def self.project
      fetch('project')
    end

    def self.project_specific
      all.select(&:project_specific?)
    end

    def self.user
      fetch('user')
    end

    # The configured user config path, abbreviated to ~ when it sits in the home
    # directory. Views use this instead of writing "~/.claude.json" out, so the
    # interface never names a file it is not actually editing.
    def self.user_config_display
      path = Rails.application.config.mcp.user_config_path.to_s

      path.sub(/\A#{Regexp.escape(Dir.home)}/, '~')
    end

    attr_reader :key

    def initialize(key)
      @key = key.to_s
      @definition = DEFINITIONS.fetch(@key)
    end

    def ==(other)
      other.is_a?(Scope) && other.key == key
    end
    alias eql? ==

    def accent
      definition[:accent]
    end

    def description
      resolve(definition[:description])
    end

    def hash
      key.hash
    end

    def location
      resolve(definition[:location])
    end

    def name
      definition[:name]
    end

    def precedence
      definition[:precedence]
    end

    def project_specific?
      definition[:project_specific]
    end

    def to_param
      key
    end

    def to_s
      key
    end

    private

    attr_reader :definition

    def resolve(text)
      Kernel.format(text, config: self.class.user_config_display)
    end
  end
end
