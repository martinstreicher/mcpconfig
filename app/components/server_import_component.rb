# The paste box above the add form.
#
# A server almost always arrives as text from somewhere else: the JSON snippet in
# a README, the `claude mcp add` line printed next to it, or the bare command.
# This offers all three straight to the form. See Mcp::ServerImport.
class ServerImportComponent < ApplicationComponent
  EXAMPLES = [
    '{ "mcpServers": { "postgres": { "command": "npx", "args": ["-y", "@mcp/postgres"] } } }',
    'claude mcp add --transport http linear https://mcp.linear.app/mcp',
    'npx -y @modelcontextprotocol/server-filesystem ~/code'
  ].freeze

  attr_reader :import, :paste, :project, :scope

  def initialize(scope:, import: nil, paste: nil, project: nil)
    @import = import
    @paste = paste
    @project = project
    @scope = scope
  end

  # Pasting a README that documents three servers is normal. Filling the form in
  # with the first and saying nothing about the rest is not.
  def extras_note
    return nil unless imported?
    return nil if import.extras.empty?

    "That paste also had #{import.extras.to_sentence} in it — paste it again to add " \
      "#{import.extras.one? ? 'that one' : 'those'}."
  end

  def filled_note
    return nil unless imported?

    "Read #{import.server.name} out of that paste. Check it over before saving."
  end

  def imported?
    import.present? && import.any?
  end

  # A pasted command can name its own scope, and the answer to whether that was
  # followed is more useful than silence either way.
  def scope_note
    key = import&.scope_key
    return nil if key.blank?

    requested = Mcp::Scope.fetch(key)
    return "Adding at #{requested.name.downcase} scope, as the command asked." if requested == scope

    "The command asked for #{requested.name.downcase} scope, which needs a project — " \
      "this form is still on #{scope.name.downcase} scope."
  end

  def url
    helpers.import_servers_path
  end
end
