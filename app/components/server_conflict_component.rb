# Shown when a save would land on a name the target scope already uses.
#
# Writing that name replaces the definition sitting there, so the save is refused
# once and this comes back with the definition at risk and a box to tick. It
# renders inside the form it guards, because the box has to be submitted with it.
class ServerConflictComponent < ApplicationComponent
  attr_reader :existing, :project, :scope

  def initialize(existing:, scope:, project: nil)
    @existing = existing
    @project = project
    @scope = scope
  end

  def existing_path
    helpers.edit_server_path(existing.name, project: project&.path, scope: scope.key)
  end

  def summary
    existing.summary.presence || 'No command configured'
  end

  def title
    "#{scope.name} scope already has a server called #{existing.name}."
  end
end
