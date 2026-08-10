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

RSpec.describe 'Overlaps' do
  let(:project) { write_project_directory('alpha') }

  before do
    write_user_config('mcpServers' => { 'shortcut' => stdio_server(command: 'npx') },
                      'projects' => { project.to_s => {} })
    write_project_config(project, 'mcpServers' => { 'shortcut' => stdio_server(command: 'bunx') })
  end

  describe 'GET /overlaps' do
    it 'lists the overriding definition', :aggregate_failures do
      get overlaps_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('shortcut')
      expect(response.body).to include('Overridden')
    end

    it 'filters to duplicates only' do
      get overlaps_path(status: 'duplicates')

      expect(response.body).to include('No duplicates to show.')
    end
  end
end
