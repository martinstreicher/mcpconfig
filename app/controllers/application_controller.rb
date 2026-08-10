class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  stale_when_importmap_changes

  helper_method :current_theme, :workspace

  rescue_from Mcp::NotFoundError, with: :render_not_found
  rescue_from Mcp::ValidationError, with: :render_invalid

  private

  # 'system' defers to the OS preference; the Stimulus theme controller resolves
  # it in the browser and writes the concrete choice back to this cookie.
  def current_theme
    theme = cookies[:theme].presence

    Theme::CHOICES.include?(theme) ? theme : Theme::DEFAULT
  end

  def project_path_param
    params[:project].presence
  end

  def render_invalid(error)
    redirect_back_or_to(root_path, alert: "That change was rejected: #{error.messages.first(3).to_sentence}")
  end

  def render_not_found(error)
    redirect_to root_path, alert: error.message
  end

  def scope_param(default: 'user')
    key = params[:scope].presence || default

    Mcp::Scope.exists?(key) ? Mcp::Scope.fetch(key) : Mcp::Scope.fetch(default)
  end

  def workspace
    @workspace ||= Mcp::Workspace.current
  end
end
