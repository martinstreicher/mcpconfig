class ProjectsController < ApplicationController
  def create
    project = workspace.add_project(params.expect(:path))

    redirect_to project_path(path: project.path), notice: "Now tracking #{project.display_name}."
  rescue Mcp::NotFoundError => e
    redirect_to projects_path, alert: e.message
  end

  def index
    @projects = workspace.projects
    @projects = @projects.select { |project| project.server_count.positive? } unless show_all?
    @projects = @projects.sort_by { |project| [-project.server_count, project.path.downcase] }
    @report = workspace.overlap_report
    @total_count = workspace.projects.size
  end

  def show
    @project = workspace.project(params.expect(:path))
    @overlaps = workspace.overlap_report.for_project(@project)
    @user_servers = workspace.user_servers
  end

  private

  def show_all?
    params[:all].present?
  end
end
