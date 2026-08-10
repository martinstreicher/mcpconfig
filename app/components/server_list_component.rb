# A filterable grid of server cards.
class ServerListComponent < ApplicationComponent
  attr_reader :empty_description, :empty_title, :overlaps, :servers, :show_scope

  def initialize(servers:, overlaps: [], show_scope: true, empty_title: 'No MCP servers here yet.',
                 empty_description: nil)
    @empty_description = empty_description
    @empty_title = empty_title
    @overlaps = overlaps
    @servers = servers
    @show_scope = show_scope
  end

  def filterable?
    servers.size > 4
  end

  def overlap_for(server)
    overlaps.find { |overlap| overlap.name == server.name }
  end
end
