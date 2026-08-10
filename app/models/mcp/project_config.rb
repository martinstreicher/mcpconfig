module Mcp
  # A project's .mcp.json — the scope that gets committed to the repository.
  class ProjectConfig
    FILENAME = '.mcp.json'.freeze
    SERVERS_KEY = 'mcpServers'.freeze

    def self.path_for(project_path)
      Pathname.new(project_path).join(FILENAME)
    end

    attr_reader :document, :project_path

    def initialize(project_path)
      @project_path = Pathname.new(project_path)
      @document = JsonDocument.new(self.class.path_for(@project_path))
    end

    def delete_server(name)
      update do |data|
        servers = data[SERVERS_KEY]
        raise NotFoundError, "no MCP server named #{name.inspect}" unless servers.is_a?(Hash) && servers.key?(name)

        servers.delete(name)
      end
    end

    def exist?
      document.exist?
    end

    def parse_error
      document.parse_error
    end

    def path
      document.path
    end

    def raw_servers
      entry = document.data[SERVERS_KEY]

      entry.is_a?(Hash) ? entry : {}
    end

    def reload
      document.reload

      self
    end

    def servers
      built = raw_servers.map do |name, config|
        Server.from_config(name, config, project_path: project_path.to_s, scope: Scope.project)
      end

      built.sort_by { |server| server.name.downcase }
    end

    def upsert_server(server, previous_name: nil)
      update do |data|
        servers = data[SERVERS_KEY]
        servers = data[SERVERS_KEY] = {} unless servers.is_a?(Hash)

        servers.delete(previous_name) if previous_name.present? && previous_name != server.name
        servers[server.name] = server.to_config
      end
    end

    def writable?
      return path.writable? if exist?

      project_path.directory? && project_path.writable?
    end

    private

    def update
      data = document.data.deep_dup
      yield(data)

      errors = Schema.errors_for(:project_file, data)
      raise ValidationError, errors if errors.any?

      document.write(data)
      reload

      data
    end
  end
end
