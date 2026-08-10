class BackupsController < ApplicationController
  before_action :assign_backup, only: %i[restore show]

  def index
    @backups = Mcp::Backup.all
    @grouped = @backups.group_by(&:source_path)
  end

  def restore
    @backup.restore
    Mcp::ChangeLog.record([@backup.source_path], source: :app)

    redirect_to backups_path,
                notice: "Restored #{@backup.source_path.basename} from #{@backup.created_at.to_fs(:long)}."
  end

  def show; end

  private

  def assign_backup
    @backup = Mcp::Backup.find(params.expect(:id)) ||
              raise(Mcp::NotFoundError, 'that backup is no longer on disk')
  end
end
