module Mcp
  # ~/.claude.json.
  #
  # Holds the user-scoped servers at the top level and the local-scoped servers
  # under projects[path]. Every write rewrites the whole document from the parsed
  # hash so unrelated keys are preserved byte-for-byte in meaning.
  class UserConfig
    SERVERS_KEY = 'mcpServers'.freeze

    attr_reader :document

    def initialize(path: nil)
      @document = JsonDocument.new(path || Rails.application.config.mcp.user_config_path)
    end

    def delete_server(name, project_path: nil)
      update do |data|
        container = servers_container(data, project_path)
        raise NotFoundError, "no MCP server named #{name.inspect}" if container.blank?

        container.delete(name)
      end
    end

    def exist?
      document.exist?
    end

    def local_servers(project_path)
      raw_local_servers(project_path).map do |name, config|
        Server.from_config(name, config, project_path: project_path, scope: Scope.local)
      end.sort_by { |server| server.name.downcase }
    end

    def parse_error
      document.parse_error
    end

    def path
      document.path
    end

    def project_entry(project_path)
      projects.fetch(project_path.to_s, {})
    end

    def project_paths
      projects.keys.sort
    end

    def projects
      data = document.data
      entry = data['projects']

      entry.is_a?(Hash) ? entry : {}
    end

    def raw_local_servers(project_path)
      entry = project_entry(project_path)[SERVERS_KEY]

      entry.is_a?(Hash) ? entry : {}
    end

    def raw_user_servers
      entry = document.data[SERVERS_KEY]

      entry.is_a?(Hash) ? entry : {}
    end

    def reload
      document.reload

      self
    end

    def replace_servers(servers, project_path: nil)
      update do |data|
        container_parent(data, project_path)[SERVERS_KEY] = servers
      end
    end

    def upsert_server(server, project_path: nil, previous_name: nil)
      update do |data|
        container = container_parent(data, project_path)
        servers = container[SERVERS_KEY]
        servers = container[SERVERS_KEY] = {} unless servers.is_a?(Hash)

        servers.delete(previous_name) if previous_name.present? && previous_name != server.name
        servers[server.name] = server.to_config
      end
    end

    def user_servers
      raw_user_servers.map { |name, config| Server.from_config(name, config, scope: Scope.user) }
                      .sort_by { |server| server.name.downcase }
    end

    private

    def container_parent(data, project_path)
      return data if project_path.blank?

      projects = data['projects']
      projects = data['projects'] = {} unless projects.is_a?(Hash)

      entry = projects[project_path.to_s]
      entry = projects[project_path.to_s] = {} unless entry.is_a?(Hash)

      entry
    end

    def servers_container(data, project_path)
      return data[SERVERS_KEY] if project_path.blank?

      data.dig('projects', project_path.to_s, SERVERS_KEY)
    end

    # Applies a change to a deep copy, validates the result, and only then
    # touches the disk.
    def update
      data = document.data.deep_dup
      yield(data)

      errors = Schema.errors_for(:user_file, data)
      raise ValidationError, errors if errors.any?

      document.write(data)
      reload

      data
    end
  end
end
