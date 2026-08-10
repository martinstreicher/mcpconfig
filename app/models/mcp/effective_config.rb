module Mcp
  # What Claude Code actually loads in one project.
  #
  # Three scopes means three files, and the interface can already show each of
  # them separately — but the question a person actually has when they open a
  # project is which definition wins. That answer is a merge across the scopes by
  # precedence, which is what this does, keeping the losing definitions next to
  # the winner so the interface can say what was overridden instead of hiding it.
  class EffectiveConfig
    # One server name, together with every definition of it that competes for it
    # in this project.
    class Entry
      attr_reader :name, :overlap, :servers

      def initialize(name:, project:, servers:)
        @name = name
        @servers = servers.sort_by { |server| -server.scope.precedence }
        @overlap = Overlap.new(name: name, project: project, servers: @servers) if @servers.size > 1
      end

      def contested?
        overlap.present?
      end

      def duplicate?
        contested? && overlap.duplicate?
      end

      # Reads as a consequence rather than a classification: what this definition
      # does to the ones it beat.
      def note
        return nil unless contested?

        verb = duplicate? ? 'Same as' : 'Overrides'

        "#{verb} #{shadowed_scope_names.to_sentence}"
      end

      def override?
        contested? && overlap.override?
      end

      def scope
        winner.scope
      end

      def shadowed
        servers.drop(1)
      end

      def warnings
        winner.warnings
      end

      def winner
        servers.first
      end

      private

      def shadowed_scope_names
        shadowed.map { |server| server.scope.name.downcase }
      end
    end

    attr_reader :project, :user_servers

    def initialize(project:, user_servers:)
      @project = project
      @user_servers = user_servers
    end

    def any?
      entries.any?
    end

    def counts
      {
        overridden: entries.count(&:override?),
        total: entries.size,
        warned: entries.count { |entry| entry.warnings.any? }
      }
    end

    def entries
      @entries ||= grouped.map { |name, servers| Entry.new(name: name, project: project, servers: servers) }
                          .sort_by { |entry| entry.name.downcase }
    end

    def from_scope(scope)
      entries.select { |entry| entry.scope == scope }
    end

    private

    def grouped
      (user_servers + project.project_servers + project.local_servers).group_by(&:name)
    end
  end
end
