# Local scope, gathered across every project.
#
# Local servers are the default for `claude mcp add`, they outrank both other
# scopes, and nothing in a repository hints that they exist — so they are the
# easiest to accumulate and forget. This view is the one place they are all
# visible at once.
class LocalServersController < ApplicationController
  def index
    @report = workspace.overlap_report
    @groups = workspace.projects
                       .reject { |project| project.local_servers.empty? }
                       .sort_by { |project| [-project.local_servers.size, project.path.downcase] }
    @total = @groups.sum { |project| project.local_servers.size }
    @warned = @groups.sum { |project| project.local_servers.count { |server| server.warnings.any? } }
  end
end
