require 'rails_helper'

RSpec.describe 'Raw configs' do
  before { write_user_config('mcpServers' => { 'postgres' => stdio_server(command: 'npx') }, 'verbose' => true) }

  describe 'GET /raw' do
    it 'shows only the mcpServers block, not the whole file', :aggregate_failures do
      get raw_config_path(scope: 'user')

      expect(response.body).to include('postgres')
      expect(response.body).not_to include('verbose')
    end
  end

  describe 'PATCH /raw' do
    it 'replaces the server block and leaves the rest of the file alone', :aggregate_failures do
      patch raw_config_path, params: {
        contents: JSON.generate('filesystem' => { 'command' => 'npx', 'type' => 'stdio' }),
        scope: 'user'
      }

      config = read_user_config

      expect(config['mcpServers'].keys).to eq(%w[filesystem])
      expect(config['verbose']).to be(true)
    end

    it 'rejects malformed JSON without writing', :aggregate_failures do
      patch raw_config_path, params: { contents: '{ "broken": ', scope: 'user' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(read_user_config['mcpServers']).to have_key('postgres')
    end

    it 'rejects a server that does not match the schema', :aggregate_failures do
      patch raw_config_path, params: {
        contents: JSON.generate('nonsense' => { 'type' => 'stdio' }),
        scope: 'user'
      }

      expect(response).to redirect_to(root_path).or have_http_status(:found)
      expect(read_user_config['mcpServers']).to have_key('postgres')
    end
  end
end
