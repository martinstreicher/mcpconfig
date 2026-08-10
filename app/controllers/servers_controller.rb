class ServersController < ApplicationController
  before_action :assign_scope
  before_action :assign_project
  before_action :assign_server, only: %i[copy create_copy destroy edit update]
  before_action :assign_existing_names, only: %i[create edit new update]

  def copy
    @targets = copy_targets
  end

  def create
    @server = build_server

    return render(:new, status: :unprocessable_content) unless @server.valid?
    return render(:new, status: :unprocessable_content) if unconfirmed_conflict?(@server.name)

    workspace.save_server(@server, project_path: @project&.path, scope: @scope)
    Mcp::ChangeLog.record([source_path], source: :app)

    redirect_to scoped_servers_path, notice: "Added #{@server.name} to #{@scope.name.downcase} scope."
  end

  def create_copy
    target_scope = requested_copy_scope
    target_project = params[:target_project].presence
    refusal = copy_refusal(target_scope, target_project)

    return render_copy(refusal) if refusal

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

  # Fills the add form in from a pasted JSON snippet, `claude mcp add` line or
  # plain command, instead of making it be transcribed a field at a time.
  def import
    @import = Mcp::ServerImport.new(params[:paste])
    @paste = params[:paste]
    @scope = imported_scope
    @server = imported_server

    assign_existing_names
    flash.now[:alert] = @import.error if @import.error

    render :new, status: @import.error ? :unprocessable_content : :ok
  end

  def index
    @servers = workspace.servers_for(project_path: @project&.path, scope: @scope)
    @overlaps = workspace.overlap_report.for_project(@project) if @project
  end

  def new
    @server = Mcp::Server.new(project_path: @project&.path, scope: @scope, transport: 'stdio')
  end

  def update
    @server = build_server

    return render(:edit, status: :unprocessable_content) unless @server.valid?
    return render(:edit, status: :unprocessable_content) if renamed? && unconfirmed_conflict?(@server.name)

    workspace.save_server(@server, previous_name: @name, project_path: @project&.path, scope: @scope)
    Mcp::ChangeLog.record([source_path], source: :app)

    redirect_to scoped_servers_path, notice: "Updated #{@server.name}."
  end

  private

  # The names already taken in this scope, so the form can say that saving would
  # replace one of them before it is submitted rather than after.
  def assign_existing_names
    @existing_names =
      if @scope.project_specific? && @project.blank?
        []
      else
        workspace.servers_for(project_path: @project&.path, scope: @scope).map(&:name)
      end
  end

  def assign_project
    return @project = nil unless @scope.project_specific?

    path = project_path_param
    raise Mcp::NotFoundError, 'that scope needs a project' if path.blank?

    @project = workspace.project(path)
  end

  def assign_scope
    @scope = scope_param
  end

  # @name is the name the server is stored under. Editing can change
  # @server.name, and both the rename and the form's own URL need the original.
  def assign_server
    @server = workspace.find_server!(params[:name], project_path: @project&.path, scope: @scope)
    @name = @server.name
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

  # Why this copy cannot go ahead as asked, if it cannot.
  def copy_refusal(scope, project_path)
    return 'Choose a project to copy this server into.' if scope.project_specific? && project_path.blank?
    return nil unless unconfirmed_conflict?(@server.name, project_path: project_path, scope: scope)

    "#{@server.name} is already defined in #{scope.name.downcase} scope — confirm the replacement below."
  end

  def copy_targets
    Mcp::Scope.all.reject { |scope| scope == @scope && !scope.project_specific? }
  end

  # A pasted command can name its own scope. It is honoured where it can be:
  # switching to a project-specific scope needs a project to switch it to.
  def imported_scope
    key = @import.scope_key
    return @scope if key.blank?

    scope = Mcp::Scope.fetch(key)
    return @scope if scope.project_specific? && @project.blank?

    scope
  end

  def imported_server
    server = @import.server || Mcp::Server.new(transport: 'stdio')
    server.project_path = @project&.path
    server.scope = @scope

    server
  end

  # Accepts "KEY=value" per line, which is how these are pasted from a shell.
  def parse_pairs(text)
    text.to_s.lines.filter_map do |line|
      line = line.strip
      next if line.blank? || line.exclude?('=')

      key, value = line.split('=', 2)
      [key.strip, value.to_s.strip]
    end.to_h
  end

  def renamed?
    @server.name != @name
  end

  def render_copy(alert)
    @targets = copy_targets

    flash.now[:alert] = alert
    render(:copy, status: :unprocessable_content)
  end

  def replace_confirmed?
    params[:replace] == '1'
  end

  def requested_copy_scope
    requested = params.expect(:target_scope).to_s
    raise Mcp::NotFoundError, "unknown scope: #{requested}" unless Mcp::Scope.exists?(requested)

    Mcp::Scope.fetch(requested)
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

  # Writing a name a scope already uses replaces what is there, so the first
  # attempt is refused and the form comes back asking for it explicitly.
  def unconfirmed_conflict?(name, scope: @scope, project_path: @project&.path)
    return false if replace_confirmed?

    @conflict = workspace.server_named(name, project_path: project_path, scope: scope)
    return false if @conflict.blank?

    # A copy is aimed somewhere other than the scope being viewed, so the panel
    # has to be told where the collision actually is.
    @conflict_project = workspace.project(project_path) if project_path.present?
    @conflict_scope = scope

    true
  end
end
