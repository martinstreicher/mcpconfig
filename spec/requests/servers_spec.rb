require 'rails_helper'

RSpec.describe 'Servers' do
  let(:project) { write_project_directory('alpha') }

  describe 'GET /servers' do
    before { write_user_config('mcpServers' => { 'postgres' => stdio_server(command: 'npx') }) }

    it 'lists the user-scoped servers', :aggregate_failures do
      get servers_path(scope: 'user')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('postgres')
    end

    it 'falls back to user scope when handed a scope that does not exist' do
      get servers_path(scope: 'nonsense')

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /servers' do
    before { write_user_config({}) }

    it 'adds a stdio server to the user scope' do
      post servers_path, params: {
        scope: 'user',
        server: { args: "-y\n@modelcontextprotocol/server-postgres", command: 'npx', name: 'postgres' }
      }

      expect(read_user_config['mcpServers']).to eq(
        'postgres' => {
          'args' => ['-y', '@modelcontextprotocol/server-postgres'],
          'command' => 'npx',
          'type' => 'stdio'
        }
      )
    end

    it 'parses NAME=value environment lines' do
      post servers_path, params: {
        scope: 'user',
        server: { command: 'npx', env: "TOKEN=abc\nLOG_LEVEL=debug", name: 'postgres' }
      }

      expect(read_user_config.dig('mcpServers', 'postgres', 'env'))
        .to eq('LOG_LEVEL' => 'debug', 'TOKEN' => 'abc')
    end

    it 'redisplays the form and writes nothing when the server is invalid', :aggregate_failures do
      post servers_path, params: { scope: 'user', server: { command: '', name: 'postgres' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(read_user_config).not_to have_key('mcpServers')
    end

    it 'writes into a project .mcp.json for project scope' do
      post servers_path, params: {
        project: project.to_s,
        scope: 'project',
        server: { command: 'npx', name: 'filesystem' }
      }

      expect(JSON.parse(project_config_path(project).read)['mcpServers']).to have_key('filesystem')
    end

    it 'writes into the project entry of the user file for local scope' do
      write_user_config('projects' => { project.to_s => {} })

      post servers_path, params: {
        project: project.to_s,
        scope: 'local',
        server: { command: 'npx', name: 'filesystem' }
      }

      expect(read_user_config.dig('projects', project.to_s, 'mcpServers')).to have_key('filesystem')
    end
  end

  describe 'PATCH /servers/:name' do
    before { write_user_config('mcpServers' => { 'postgres' => stdio_server(command: 'npx') }) }

    it 'renames without leaving the old entry behind', :aggregate_failures do
      patch server_path('postgres', scope: 'user'), params: {
        scope: 'user',
        server: { command: 'npx', name: 'pg' }
      }

      servers = read_user_config['mcpServers']

      expect(servers).to have_key('pg')
      expect(servers).not_to have_key('postgres')
    end

    it 'takes a backup before changing anything' do
      expect { patch server_path('postgres', scope: 'user'), params: { scope: 'user', server: { command: 'bunx', name: 'postgres' } } }
        .to change { Mcp::Backup.all.size }.by(1)
    end
  end

  describe 'DELETE /servers/:name' do
    before do
      write_user_config('mcpServers' => { 'keep' => stdio_server(command: 'npx'), 'postgres' => stdio_server(command: 'npx') })
    end

    it 'removes only the named server' do
      delete server_path('postgres', scope: 'user')

      expect(read_user_config['mcpServers'].keys).to eq(%w[keep])
    end

    it 'redirects with a message when the server is already gone', :aggregate_failures do
      delete server_path('missing', scope: 'user')

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe 'POST /servers/:name/copy' do
    before do
      write_user_config('mcpServers' => { 'postgres' => stdio_server(command: 'npx') },
                        'projects' => { project.to_s => {} })
    end

    it 'copies a user server into a project without disturbing the original', :aggregate_failures do
      post copy_server_path('postgres', scope: 'user'),
           params: { target_project: project.to_s, target_scope: 'project' }

      expect(JSON.parse(project_config_path(project).read)['mcpServers']).to have_key('postgres')
      expect(read_user_config['mcpServers']).to have_key('postgres')
    end

    it 'refuses a project-scoped copy with no project chosen', :aggregate_failures do
      post copy_server_path('postgres', scope: 'user'), params: { target_scope: 'project' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(flash.now[:alert]).to be_present
    end
  end
end
