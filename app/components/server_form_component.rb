# The add/edit form for a single server.
#
# Transport choice drives which half of the form is relevant, so the two halves
# are both rendered and toggled client-side rather than round-tripping.
class ServerFormComponent < ApplicationComponent
  NAME_HINT = 'Letters, numbers, dashes, dots and underscores.'.freeze

  attr_reader :conflict, :existing_names, :original_name, :project, :scope, :server, :url

  def initialize(server:, scope:, url:, conflict: nil, existing_names: [], original_name: nil, project: nil)
    @conflict = conflict
    @existing_names = existing_names
    @original_name = original_name
    @project = project
    @scope = scope
    @server = server
    @url = url
  end

  def args_text
    server.args.join("\n")
  end

  def cancel_path
    helpers.servers_path(project: project&.path, scope: scope.key)
  end

  # Keeping the name a server already has is not a collision with itself.
  def collision_names
    existing_names - [original_name].compact
  end

  def env_text
    pairs_text(server.env)
  end

  def headers_text
    pairs_text(server.headers)
  end

  def new_record?
    original_name.blank?
  end

  def submit_label
    return "Replace #{conflict.name}" if conflict
    return 'Save changes' unless new_record?

    'Add server'
  end

  def transport_options
    Mcp::Server::TRANSPORTS.map { |transport| [transport_label(transport), transport] }
  end

  private

  def pairs_text(pairs)
    pairs.sort.map { |key, value| "#{key}=#{value}" }.join("\n")
  end

  def transport_label(transport)
    case transport
    when 'http' then 'http — remote server over HTTP'
    when 'sse' then 'sse — remote server over server-sent events'
    else 'stdio — local process'
    end
  end
end
