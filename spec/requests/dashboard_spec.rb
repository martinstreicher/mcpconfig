require 'rails_helper'

RSpec.describe 'Dashboard' do
  describe 'GET /' do
    it 'renders when there is no config file at all' do
      user_config_path.delete

      get root_path

      expect(response).to have_http_status(:ok)
    end

    it 'explains itself instead of crashing on a malformed config', :aggregate_failures do
      user_config_path.write('{ "broken": ')

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('could not be parsed')
    end

    it 'surfaces an overlap between a project and user scope' do
      project = write_project_directory('alpha')
      write_user_config('mcpServers' => { 'shortcut' => stdio_server(command: 'npx') },
                        'projects' => { project.to_s => {} })
      write_project_config(project, 'mcpServers' => { 'shortcut' => stdio_server(command: 'bunx') })

      get root_path

      expect(response.body).to include('Overlaps needing attention')
    end
  end
end
