class OverlapsController < ApplicationController
  def index
    @report = workspace.overlap_report
    @grouped = filtered(@report).group_by(&:project).sort_by { |project, entries| [-entries.size, project.path] }
    @filter = params[:status].presence
  end

  private

  def filtered(report)
    case @filter = params[:status].presence
    when 'duplicates' then report.duplicates
    when 'overrides' then report.overrides
    else report.overlaps
    end
  end
end
