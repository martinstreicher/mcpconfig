class DashboardController < ApplicationController
  def show
    @overlap_report = workspace.overlap_report
    @projects = workspace.projects_with_servers.sort_by { |project| -project.server_count }
    @stats = workspace.stats
    @user_servers = workspace.user_servers
  end
end
