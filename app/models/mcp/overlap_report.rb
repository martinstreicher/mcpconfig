module Mcp
  # Finds every server name that is defined in more than one scope for the same
  # project.
  #
  # Two projects declaring the same server name is not an overlap: they never
  # apply at the same time. Only definitions that compete within one project do.
  class OverlapReport
    attr_reader :workspace

    def initialize(workspace)
      @workspace = workspace
    end

    def any?
      overlaps.any?
    end

    # Overlaps grouped by project, projects with the most first.
    def by_project
      overlaps.group_by(&:project).sort_by { |project, entries| [-entries.size, project.path] }
    end

    def counts
      {
        duplicates: duplicates.size,
        overrides: overrides.size,
        projects: overlaps.map(&:project).uniq.size,
        total: overlaps.size
      }
    end

    def duplicates
      overlaps.select(&:duplicate?)
    end

    def for_project(project)
      overlaps.select { |overlap| overlap.project.path == project.path }
    end

    def for_server_name(name)
      overlaps.select { |overlap| overlap.name == name }
    end

    def overlaps
      @overlaps ||= workspace.projects.flat_map { |project| overlaps_for(project) }
                             .sort_by { |overlap| [overlap.duplicate? ? 1 : 0, overlap.project.path, overlap.name] }
    end

    def overrides
      overlaps.select(&:override?)
    end

    # Names defined at user scope that no project touches. Useful as the
    # reassuring half of the report.
    def unshadowed_user_servers
      shadowed = overlaps.flat_map { |overlap| overlap.servers.map(&:name) }.uniq

      workspace.user_servers.reject { |server| shadowed.include?(server.name) }
    end

    private

    def overlaps_for(project)
      project_servers = project.project_servers + project.local_servers
      return [] if project_servers.empty?

      candidates = workspace.user_servers + project_servers

      candidates.group_by(&:name).filter_map do |name, servers|
        next if servers.size < 2

        Overlap.new(name: name, project: project, servers: servers)
      end
    end
  end
end
