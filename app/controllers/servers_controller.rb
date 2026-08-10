class ServersController < ApplicationController
  before_action :assign_scope
  before_action :assign_project
  before_action :assign_server, only: %i[copy create_copy destroy edit update]

  def copy
    @targets = copy_targets
  end

  def create
    @server = build_server

    return render(:new, status: :unprocessable_content) unless @server.valid?

    workspace.save_server(@server, project_path: @project&.path, scope: @scope)
    Mcp::ChangeLog.record([source_path], source: :app)

    redirect_to scoped_servers_path, notice: "Added #{@server.name} to #{@scope.name.downcase} scope."
  end

  def create_copy
    requested = params.require(:target_scope).to_s
    raise Mcp::NotFoundError, "unknown scope: #{requested}" unless Mcp::Scope.exists?(requested)

    target_scope = Mcp::Scope.fetch(requested)
    target_project = params[:target_project].presence

    if target_scope.project_specific? && target_project.blank?
      @targets = copy_targets

      flash.now[:alert] = 'Choose a project to copy this server into.'
      return render(:copy, status: :unprocessable_content)
    end

    workspace.copy_server(@server, to_project_path: target_project, to_scope: target_scope)
    Mcp::ChangeLog.record([source_path], source: :app)

    redirect_to servers_path(project: target_project, scope: target_scope.key),
                notice: "Copied #{@server.name} into #{target_scope.name.downcase} scope."
  end

  def destroy
    workspace.delete_server(@server.name, project_path: @project&.path, scope: @scope)
    Mcp::ChangeLog.record([source_path], source: :app)

    redirect_to scoped_servers_path, notice: "Removed #{@server.name}."
  end

  def edit; end

  def index
    @servers = workspace.servers_for(project_path: @project&.path, scope: @scope)
    @overlaps = workspace.overlap_report.for_project(@project) if @project
  end

  def new
    @server = Mcp::Server.new(project_path: @project&.path, scope: @scope, transport: 'stdio')
  end

  def update
    previous_name = @server.name
    @server = build_server

    return render(:edit, status: :unprocessable_content) unless @server.valid?

    workspace.save_server(@server, previous_name: previous_name, project_path: @project&.path, scope: @scope)
    Mcp::ChangeLog.record([source_path], source: :app)

    redirect_to scoped_servers_path, notice: "Updated #{@server.name}."
  end

  private

  def assign_project
    return @project = nil unless @scope.project_specific?

    path = project_path_param
    raise Mcp::NotFoundError, 'that scope needs a project' if path.blank?

    @project = workspace.project(path)
  end

  def assign_scope
    @scope = scope_param
  end

  def assign_server
    @server = workspace.find_server!(params[:name], project_path: @project&.path, scope: @scope)
  end

  def build_server
    attributes = server_params

    Mcp::Server.new(
      args: split_lines(attributes[:args]),
      command: attributes[:command],
      env: parse_pairs(attributes[:env]),
      extras: @server&.extras || {},
      headers: parse_pairs(attributes[:headers]),
      name: attributes[:name].to_s.strip,
      project_path: @project&.path,
      scope: @scope,
      transport: attributes[:transport].presence || 'stdio',
      url: attributes[:url]
    )
  end

  def copy_targets
    Mcp::Scope.all.reject { |scope| scope == @scope && !scope.project_specific? }
  end

  # Accepts "KEY=value" per line, which is how these are pasted from a shell.
  def parse_pairs(text)
    text.to_s.lines.filter_map do |line|
      line = line.strip
      next if line.blank? || !line.include?('=')

      key, value = line.split('=', 2)
      [key.strip, value.to_s.strip]
    end.to_h
  end

  def scoped_servers_path
    servers_path(project: @project&.path, scope: @scope.key)
  end

  def server_params
    params.expect(server: %i[args command env headers name transport url])
  end

  def source_path
    return workspace.project_config(@project.path).path if @scope == Mcp::Scope.project

    workspace.user_config.path
  end

  def split_lines(text)
    text.to_s.lines.map(&:strip).compact_blank
  end
end
