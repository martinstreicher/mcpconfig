require 'rails_helper'

RSpec.describe 'Backups' do
  before do
    write_user_config('mcpServers' => { 'postgres' => stdio_server(command: 'npx') })

    # One edit, so exactly one backup of the original exists.
    patch server_path('postgres', scope: 'user'), params: { scope: 'user', server: { command: 'bunx', name: 'postgres' } }
  end

  describe 'GET /backups' do
    it 'lists the backup taken before the edit', :aggregate_failures do
      get backups_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('postgres')
    end
  end

  describe 'POST /backups/:id/restore' do
    it 'puts the previous contents back', :aggregate_failures do
      backup = Mcp::Backup.all.sole

      expect(read_user_config.dig('mcpServers', 'postgres', 'command')).to eq('bunx')

      post restore_backup_path(backup)

      expect(read_user_config.dig('mcpServers', 'postgres', 'command')).to eq('npx')
    end

    it 'backs up the current file first, so the restore is itself undoable' do
      backup = Mcp::Backup.all.sole

      expect { post restore_backup_path(backup) }.to change { Mcp::Backup.all.size }.by(1)
    end

    it 'reports a backup that is no longer on disk', :aggregate_failures do
      post restore_backup_path('missing-backup')

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to be_present
    end
  end
end
