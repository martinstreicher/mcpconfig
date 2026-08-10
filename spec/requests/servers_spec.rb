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

  # These three render-only actions had no coverage until a missing helper
  # method took two of them down in development without a single spec failing.
  describe 'the forms' do
    before { write_user_config('mcpServers' => { 'postgres' => stdio_server(command: 'npx') }) }

    it 'renders the new-server form' do
      get new_server_path(scope: 'user')

      expect(response).to have_http_status(:ok)
    end

    it 'renders the edit form' do
      get edit_server_path('postgres', scope: 'user')

      expect(response).to have_http_status(:ok)
    end

    it 'renders the copy form with the other scopes offered', :aggregate_failures do
      get copy_server_path('postgres', scope: 'user')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Project').and include('Local')
    end

    it 'renders the new-server form for a project scope' do
      write_user_config('projects' => { project.to_s => {} })

      get new_server_path(project: project.to_s, scope: 'project')

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

  describe 'POST /servers/import' do
    before { write_user_config({}) }

    it 'fills the form in from a pasted JSON snippet without writing anything', :aggregate_failures do
      post import_servers_path, params: {
        paste: '{"mcpServers": {"postgres": {"command": "npx", "args": ["-y", "pg"]}}}',
        scope: 'user'
      }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('postgres').and include('npx')
      expect(read_user_config).not_to have_key('mcpServers')
    end

    it 'fills the form in from a claude mcp add command' do
      post import_servers_path, params: { paste: 'claude mcp add --transport http linear https://mcp.linear.app/mcp',
                                          scope: 'user' }

      expect(response.body).to include('linear').and include('https://mcp.linear.app/mcp')
    end

    it 'explains a paste it cannot read and still renders the form', :aggregate_failures do
      post import_servers_path, params: { paste: '{"mcpServers": {', scope: 'user' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(flash.now[:alert]).to start_with('That is not valid JSON')
    end

    it 'honours a scope the pasted command asks for' do
      post import_servers_path, params: { paste: 'claude mcp add -s user postgres -- npx', scope: 'user' }

      expect(response.body).to include('as the command asked')
    end
  end

  describe 'replacing a name that is already taken' do
    before { write_user_config('mcpServers' => { 'postgres' => stdio_server(command: 'npx') }) }

    it 'refuses the first attempt and leaves the definition alone', :aggregate_failures do
      post servers_path, params: { scope: 'user', server: { command: 'bunx', name: 'postgres' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('already has a server called postgres')
      expect(read_user_config.dig('mcpServers', 'postgres', 'command')).to eq('npx')
    end

    it 'goes through once the replacement is confirmed' do
      post servers_path, params: { replace: '1', scope: 'user', server: { command: 'bunx', name: 'postgres' } }

      expect(read_user_config.dig('mcpServers', 'postgres', 'command')).to eq('bunx')
    end

    it 'refuses a rename onto another existing name', :aggregate_failures do
      write_user_config('mcpServers' => { 'keep' => stdio_server(command: 'npx'),
                                          'postgres' => stdio_server(command: 'bunx') })

      patch server_path('postgres', scope: 'user'), params: { scope: 'user', server: { command: 'bunx', name: 'keep' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(read_user_config['mcpServers'].keys).to eq(%w[keep postgres])
    end

    it 'refuses a copy that would land on an existing name', :aggregate_failures do
      project.join('.mcp.json').write(JSON.generate('mcpServers' => { 'postgres' => stdio_server(command: 'uvx') }))
      write_user_config('mcpServers' => { 'postgres' => stdio_server(command: 'npx') },
                        'projects' => { project.to_s => {} })

      post copy_server_path('postgres', scope: 'user'),
           params: { target_project: project.to_s, target_scope: 'project' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(project_config_path(project).read).dig('mcpServers', 'postgres', 'command')).to eq('uvx')
    end

    it 'lets an editor keep its own name' do
      patch server_path('postgres', scope: 'user'),
            params: { scope: 'user', server: { command: 'bunx', name: 'postgres' } }

      expect(read_user_config.dig('mcpServers', 'postgres', 'command')).to eq('bunx')
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
      expect do
        patch server_path('postgres', scope: 'user'),
              params: { scope: 'user', server: { command: 'bunx', name: 'postgres' } }
      end
        .to change { Mcp::Backup.all.size }.by(1)
    end
  end

  describe 'DELETE /servers/:name' do
    before do
      write_user_config('mcpServers' => { 'keep' => stdio_server(command: 'npx'),
                                          'postgres' => stdio_server(command: 'npx') })
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
