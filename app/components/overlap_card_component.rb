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

  def delete_path_for(server)
    helpers.server_path(server.name, project: server.project_path, scope: server.scope.key)
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

  def in_effect?(server)
    server.equal?(overlap.winner)
  end

  # The redundant copies are the point of a duplicate card, so their Remove reads
  # as the action to take. Everything else stays quiet.
  def removal_classes(server)
    base = 'rounded-lg border border-transparent px-2 py-0.5 text-xs font-medium transition-colors'

    if in_effect?(server)
      "#{base} text-slate-500 hover:bg-slate-100 dark:text-slate-400 dark:hover:bg-slate-800"
    else
      "#{base} text-rose-600 hover:bg-rose-50 dark:text-rose-400 dark:hover:bg-rose-950/50"
    end
  end

  # Removing a definition from this card is a one-click change to what Claude Code
  # loads, so the confirmation says which way it goes rather than asking "are you
  # sure". A shadowed copy is already doing nothing; the winner is not.
  def removal_confirmation(server)
    scope = server.scope.name.downcase

    unless in_effect?(server)
      return "Remove the #{scope} definition of #{overlap.name}? The " \
             "#{overlap.winner.scope.name.downcase} one already wins, so what runs does not change."
    end

    successor = overlap.shadowed.first

    "Remove the #{scope} definition of #{overlap.name}? The #{successor.scope.name.downcase} one " \
      "takes over, so #{successor.summary.presence || 'a server with no command'} runs instead."
  end
end
