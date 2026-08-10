# Local scope, gathered across every project.
#
# Local servers are the default for `claude mcp add`, they outrank both other
# scopes, and nothing in a repository hints that they exist — so they are the
# easiest to accumulate and forget. This view is the one place they are all
# visible at once.
class LocalServersController < ApplicationController
  def index
    @groups = workspace.projects_with_local_servers
    @report = workspace.overlap_report
    @servers = @groups.flat_map(&:local_servers)
  end
end
