# The merged view of one project: every server Claude Code will load there, which
# scope each one came from, and what it beat to get there.
#
# The per-scope lists further down the page are still the place to edit; this is
# the place to find out what is actually in effect. See Mcp::EffectiveConfig.
class EffectiveConfigComponent < ApplicationComponent
  attr_reader :config

  def initialize(config:)
    @config = config
  end

  def edit_path_for(entry)
    server = entry.winner

    helpers.edit_server_path(
      server.name,
      project: (config.project.path if server.scope.project_specific?),
      scope: server.scope.key
    )
  end

  def note_accent(entry)
    entry.duplicate? ? 'slate' : 'rose'
  end

  def overlap_path_for(entry)
    helpers.overlaps_path(anchor: entry.overlap.id)
  end

  def summary
    tally = config.counts
    parts = ["#{tally[:total]} #{'server'.pluralize(tally[:total])} in effect"]

    parts << "#{tally[:overridden]} overridden" if tally[:overridden].positive?
    parts << "#{tally[:warned]} with warnings" if tally[:warned].positive?

    parts.join(' · ')
  end

  def warning_title(entry)
    entry.warnings.map(&:message).join(' ')
  end
end
