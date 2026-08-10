module Mcp
  # Aggregate root. Everything the UI reads or writes goes through here so the
  # controllers never touch a file path directly.
  #
  # A workspace is cheap and request-scoped: it memoises the parsed documents for
  # the life of one request and is thrown away afterwards, which keeps it honest
  # about a file that changed underneath it.
  class Workspace
    def self.current
      new
    end

    def add_project(path)
      expanded = Pathname.new(path.to_s).expand_path
      raise NotFoundError, "#{expanded} is not a directory" unless expanded.directory?

      user_config.replace_servers(user_config.raw_local_servers(expanded.to_s), project_path: expanded.to_s)

      project(expanded.to_s)
    end

    def copy_server(server, to_scope:, to_project_path: nil)
      target = server.dup
      target.scope = to_scope
      target.project_path = to_project_path

      save_server(target, scope: to_scope, project_path: to_project_path)
    end

    def delete_server(name, scope:, project_path: nil)
      scope = Scope.fetch(scope)

      if scope == Scope.project
        project_config(project_path).delete_server(name)
      else
        user_config.delete_server(name, project_path: scope.project_specific? ? project_path : nil)
      end
    end

    def find_server!(name, scope:, project_path: nil)
      servers_for(scope: scope, project_path: project_path).find { |server| server.name == name } ||
        raise(NotFoundError, "no #{scope} MCP server named #{name.inspect}")
    end

    def overlap_report
      @overlap_report ||= OverlapReport.new(self)
    end

    def project(path)
      projects_by_path[path.to_s] ||= Project.new(path, user_config: user_config)
    end

    def project_config(path)
      project(path).config_file
    end

    def projects
      @projects ||= user_config.project_paths.map { |path| project(path) }
    end

    # Only the projects that have something to show, which is what the UI leads
    # with — a machine with 90 remembered project paths and 3 real MCP setups
    # should not open on 90 empty cards.
    def projects_with_servers
      projects.select { |project| project.server_count.positive? }
    end

    def save_server(server, scope:, project_path: nil, previous_name: nil)
      scope = Scope.fetch(scope)
      raise ArgumentError, 'a project path is required for this scope' if scope.project_specific? && project_path.blank?

      if scope == Scope.project
        project_config(project_path).upsert_server(server, previous_name: previous_name)
      else
        user_config.upsert_server(
          server,
          previous_name: previous_name,
          project_path: scope.project_specific? ? project_path : nil
        )
      end

      server
    end

    def servers_for(scope:, project_path: nil)
      scope = Scope.fetch(scope)
      return user_servers unless scope.project_specific?

      project(project_path).servers_in(scope)
    end

    def stats
      {
        backups: Backup.all.size,
        overlaps: overlap_report.counts[:total],
        projects: projects_with_servers.size,
        user_servers: user_servers.size
      }
    end

    def user_config
      @user_config ||= UserConfig.new
    end

    def user_servers
      @user_servers ||= user_config.user_servers
    end

    private

    def projects_by_path
      @projects_by_path ||= {}
    end
  end
end
