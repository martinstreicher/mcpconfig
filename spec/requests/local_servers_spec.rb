require 'rails_helper'

RSpec.describe 'Local servers' do
  let(:one) { write_project_directory('alpha') }
  let(:two) { write_project_directory('beta') }

  describe 'GET /local' do
    before do
      write_user_config(
        'mcpServers' => { 'postgres' => stdio_server(command: 'npx') },
        'projects' => {
          one.to_s => { 'mcpServers' => { 'figma' => { 'type' => 'stdio', 'command' => 'http://127.0.0.1:3845/mcp' } } },
          two.to_s => { 'mcpServers' => { 'sentry' => stdio_server(command: 'npx') } }
        }
      )
    end

    it 'gathers local servers from every project', :aggregate_failures do
      get local_servers_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('figma').and include('sentry')
    end

    it 'leaves user-scoped servers out of it' do
      get local_servers_path

      expect(response.body).not_to include('postgres')
    end

    it 'surfaces the warning on a misconfigured server' do
      get local_servers_path

      expect(response.body).to include('its command is a URL')
    end

    it 'says so when there are none' do
      write_user_config('mcpServers' => { 'postgres' => stdio_server(command: 'npx') })

      get local_servers_path

      expect(response.body).to include('No local-scope servers.')
    end
  end
end
