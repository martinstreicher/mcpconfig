# The add/edit form for a single server.
#
# Transport choice drives which half of the form is relevant, so the two halves
# are both rendered and toggled client-side rather than round-tripping.
class ServerFormComponent < ApplicationComponent
  attr_reader :project, :scope, :server, :url

  def initialize(server:, scope:, url:, project: nil)
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

  def env_text
    pairs_text(server.env)
  end

  def headers_text
    pairs_text(server.headers)
  end

  def new_record?
    server.name.blank?
  end

  def submit_label
    new_record? ? 'Add server' : 'Save changes'
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
