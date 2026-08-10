require 'rails_helper'

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
