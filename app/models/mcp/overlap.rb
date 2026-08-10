module Mcp
  # One server name defined in more than one scope for the same project.
  #
  # Overlaps are not automatically bad — re-declaring a server locally is a
  # normal way to override a team default — so they are classified rather than
  # simply reported. A +duplicate+ is redundant; an +override+ genuinely changes
  # what runs.
  class Overlap
    COMPARED_FIELDS = %i[transport command args env url headers].freeze

    attr_reader :name, :project, :servers

    def initialize(name:, project:, servers:)
      @name = name
      @project = project
      @servers = servers.sort_by { |server| -server.scope.precedence }
    end

    # True when the winning definition comes from a project scope and hides a
    # user-scoped one. This is the case worth a second look.
    def crosses_user_and_project?
      scopes.include?(Scope.user) && scopes.any?(&:project_specific?)
    end

    # Field-level diff across the definitions, for the fields that actually vary.
    def differences
      COMPARED_FIELDS.filter_map do |field|
        values = servers.index_by { |server| server.scope.key }.transform_values { |server| server.public_send(field) }
        next if values.values.uniq.size <= 1

        { field: field, values: values }
      end
    end

    def duplicate?
      status == :duplicate
    end

    def id
      [project.path, name].join('::')
    end

    def override?
      status == :override
    end

    def scopes
      servers.map(&:scope)
    end

    def severity
      return :info if duplicate?

      crosses_user_and_project? ? :warning : :notice
    end

    # Definitions that are present but never used, because a higher-precedence
    # scope defines the same name.
    def shadowed
      servers.drop(1)
    end

    def status
      @status ||= servers.map(&:fingerprint).uniq.size == 1 ? :duplicate : :override
    end

    def summary
      return duplicate_summary if duplicate?

      override_summary
    end

    # The definition Claude Code actually uses: highest precedence wins.
    def winner
      servers.first
    end

    private

    def duplicate_summary
      "Defined identically in #{scope_names.to_sentence}. The #{winner.scope.name.downcase} copy wins; " \
        'the others are redundant.'
    end

    def override_summary
      shadowed_names = shadowed.map { |server| server.scope.name.downcase }

      "#{winner.scope.name} overrides #{shadowed_names.to_sentence} " \
        "for #{differences.pluck(:field).to_sentence}."
    end

    def scope_names
      scopes.map(&:name)
    end
  end
end
