module Mcp
  # The three places Claude Code looks for MCP server definitions.
  #
  # When the same server name appears in more than one of them the highest
  # precedence wins, which is what makes overlaps worth surfacing.
  class Scope
    DEFINITIONS = {
      'user' => {
        accent: 'indigo',
        description: 'Available in every project on this machine.',
        location: '~/.claude.json → mcpServers',
        name: 'User',
        precedence: 1,
        project_specific: false
      },
      'project' => {
        accent: 'emerald',
        description: 'Checked into the repository and shared with the team.',
        location: '<project>/.mcp.json → mcpServers',
        name: 'Project',
        precedence: 2,
        project_specific: true
      },
      'local' => {
        accent: 'amber',
        description: 'Private to you, stored per project path in ~/.claude.json.',
        location: '~/.claude.json → projects[path].mcpServers',
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
      definition[:description]
    end

    def hash
      key.hash
    end

    def location
      definition[:location]
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
  end
end
