module Mcp
  # One project path, pulling together both project-scoped sources: the .mcp.json
  # in the directory and the local entry inside ~/.claude.json.
  class Project
    attr_reader :path, :user_config

    def initialize(path, user_config:)
      @path = path.to_s
      @user_config = user_config
    end

    def config_file
      @config_file ||= ProjectConfig.new(path)
    end

    def directory?
      pathname.directory?
    end

    def disabled_mcpjson_servers
      Array(entry['disabledMcpjsonServers'])
    end

    def display_name
      pathname.basename.to_s
    end

    def enabled_mcpjson_servers
      Array(entry['enabledMcpjsonServers'])
    end

    def entry
      user_config.project_entry(path)
    end

    def last_run_at
      value = entry['lastRun'] || entry['lastStartTime']
      return nil if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError
      nil
    end

    def local_servers
      @local_servers ||= user_config.local_servers(path)
    end

    def pathname
      @pathname ||= Pathname.new(path)
    end

    def project_servers
      @project_servers ||= config_file.servers
    end

    def relative_path
      path.sub(/\A#{Regexp.escape(Dir.home)}/, '~')
    end

    def server_count
      servers.size
    end

    def servers
      local_servers + project_servers
    end

    def servers_in(scope)
      scope == Scope.local ? local_servers : project_servers
    end

    def to_param
      path
    end
  end
end
