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

    it 'offers Remove for both competing definitions', :aggregate_failures do
      get overlaps_path

      expect(response.body).to include('scope=project')
      expect(response.body).to include('Remove')
    end
  end

  describe 'clearing an overlap from the page that reported it' do
    it 'removes the project definition and resolves the overlap', :aggregate_failures do
      delete server_path('shortcut', project: project.to_s, scope: 'project'),
             headers: { 'HTTP_REFERER' => overlaps_path }

      expect(response).to redirect_to(overlaps_path)
      expect(flash[:notice]).to eq('Removed shortcut.')
      expect(Mcp::Workspace.current.overlap_report.overlaps).to be_empty
    end

    it 'leaves the user definition alone', :aggregate_failures do
      delete server_path('shortcut', project: project.to_s, scope: 'project'),
             headers: { 'HTTP_REFERER' => overlaps_path }

      expect(read_user_config.dig('mcpServers', 'shortcut', 'command')).to eq('npx')
      expect(JSON.parse(project_config_path(project).read)['mcpServers']).to be_empty
    end

    it 'removes the user definition when that is the one asked for', :aggregate_failures do
      delete server_path('shortcut', scope: 'user'), headers: { 'HTTP_REFERER' => overlaps_path }

      expect(read_user_config['mcpServers']).to be_empty
      expect(JSON.parse(project_config_path(project).read).dig('mcpServers', 'shortcut', 'command')).to eq('bunx')
    end

    it 'comes back to a project page when that is where the card was' do
      referer = project_path(path: project.to_s)

      delete server_path('shortcut', project: project.to_s, scope: 'project'),
             headers: { 'HTTP_REFERER' => referer }

      expect(response).to redirect_to(referer)
    end

    it 'still falls back to the server list when there is no referer' do
      delete server_path('shortcut', project: project.to_s, scope: 'project')

      expect(response).to redirect_to(servers_path(project: project.to_s, scope: 'project'))
    end
  end
end
