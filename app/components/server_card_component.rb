# One MCP server, shown as a card with its transport, command line, environment
# and the actions that apply to it.
class ServerCardComponent < ApplicationComponent
  TRANSPORT_ACCENTS = { 'http' => 'rose', 'sse' => 'rose', 'stdio' => 'slate' }.freeze

  attr_reader :overlap, :project, :server, :show_scope

  def initialize(server:, overlap: nil, project: nil, show_scope: true)
    @overlap = overlap
    @project = project
    @server = server
    @show_scope = show_scope
  end

  def copy_path
    helpers.copy_server_path(server.name, **scope_params)
  end

  def delete_path
    helpers.server_path(server.name, **scope_params)
  end

  def edit_path
    helpers.edit_server_path(server.name, **scope_params)
  end

  def env_pairs
    server.env.sort.to_h
  end

  def masked(value)
    return value if value.length < 12

    "#{value.first(4)}#{'•' * 8}#{value.last(4)}"
  end

  # Environment values that look like credentials are masked until asked for.
  def secret?(key)
    key.match?(Mcp::Server::SECRET_NAME)
  end

  def transport_accent
    TRANSPORT_ACCENTS.fetch(server.transport, 'slate')
  end

  private

  def scope_params
    { project: server.project_path, scope: server.scope.key }.compact
  end
end
