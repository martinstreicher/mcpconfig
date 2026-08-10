# One overlapping server name, with the competing definitions side by side and
# the field-level differences called out.
class OverlapCardComponent < ApplicationComponent
  attr_reader :overlap, :show_project

  def initialize(overlap:, show_project: true)
    @overlap = overlap
    @show_project = show_project
  end

  def accent_name
    overlap.duplicate? ? 'slate' : 'rose'
  end

  def display_value(value)
    return '—' if value.blank?
    return value.join(' ') if value.is_a?(Array)
    return value.map { |key, entry| "#{key}=#{entry}" }.join(', ') if value.is_a?(Hash)

    value.to_s
  end

  def edit_path_for(server)
    helpers.edit_server_path(server.name, project: server.project_path, scope: server.scope.key)
  end

  def headline
    overlap.duplicate? ? 'Identical duplicate' : 'Overridden'
  end
end
