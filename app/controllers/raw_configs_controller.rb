# Direct JSON editing, for the cases the structured editor cannot reach.
#
# Only the mcpServers fragment is editable here. Handing someone a textarea
# containing their entire ~/.claude.json — OAuth account, session history, cached
# feature flags — invites a mistake this app cannot undo for them.
class RawConfigsController < ApplicationController
  before_action :assign_scope
  before_action :assign_project

  def edit
    @document = document_for_display
  end

  def show
    @document = document_for_display
  end

  def update
    parsed = JSON.parse(params.require(:contents))
    raise JSON::ParserError, 'expected a JSON object of server names' unless parsed.is_a?(Hash)

    errors = Mcp::Schema.errors_for(:server_map, parsed)
    raise Mcp::ValidationError, errors if errors.any?

    write(parsed)
    Mcp::ChangeLog.record([source_path], source: :app)

    redirect_to raw_config_path(project: @project&.path, scope: @scope.key),
                notice: 'Saved the MCP server block.'
  rescue JSON::ParserError => e
    @contents = params[:contents]
    @document = document_for_display

    flash.now[:alert] = "That is not valid JSON: #{e.message.truncate(160)}"
    render :edit, status: :unprocessable_content
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

  def document_for_display
    JSON.pretty_generate(raw_servers)
  end

  def raw_servers
    case @scope.key
    when 'local' then workspace.user_config.raw_local_servers(@project.path)
    when 'project' then workspace.project_config(@project.path).raw_servers
    else workspace.user_config.raw_user_servers
    end
  end

  def source_path
    return workspace.project_config(@project.path).path if @scope == Mcp::Scope.project

    workspace.user_config.path
  end

  def write(servers)
    if @scope == Mcp::Scope.project
      config = workspace.project_config(@project.path)
      data = config.document.data.deep_dup
      data['mcpServers'] = servers

      config.document.write(data)
    else
      workspace.user_config.replace_servers(servers, project_path: @project&.path)
    end
  end
end
