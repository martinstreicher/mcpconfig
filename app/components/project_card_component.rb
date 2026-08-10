# A project summarised: how many servers it defines in each scope, and whether
# any of them collide with the user-scoped ones.
class ProjectCardComponent < ApplicationComponent
  attr_reader :overlaps, :project

  def initialize(project:, overlaps: [])
    @overlaps = overlaps
    @project = project
  end

  def accent_name
    return 'rose' if overrides.any?
    return 'emerald' if project.project_servers.any?

    'amber'
  end

  def duplicates
    overlaps.select(&:duplicate?)
  end

  def missing_directory?
    !project.directory?
  end

  def overrides
    overlaps.select(&:override?)
  end

  def path
    helpers.project_path(path: project.path)
  end
end
