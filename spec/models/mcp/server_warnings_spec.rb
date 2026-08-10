require 'rails_helper'

RSpec.describe 'Mcp::Server warnings' do
  def server_for(config)
    Mcp::Server.from_config('example', config)
  end

  describe 'a stdio command that is really a URL' do
    subject(:warning) { server_for({ 'type' => 'stdio', 'command' => 'http://127.0.0.1:3845/mcp' }).warnings.sole }

    it 'is flagged', :aggregate_failures do
      expect(warning.code).to eq(:url_as_command)
      expect(warning.field).to eq(:command)
      expect(warning.suggestion).to include('http')
    end

    it 'does not make the server invalid, so it can still be edited' do
      expect(server_for({ 'type' => 'stdio', 'command' => 'http://127.0.0.1:3845/mcp' })).to be_valid
    end

    it 'is not raised for the correctly configured twin' do
      server = server_for({ 'type' => 'http', 'url' => 'http://127.0.0.1:3845/mcp' })

      expect(server.warnings).to be_empty
    end

    it 'is not raised for an ordinary command' do
      expect(server_for({ 'command' => 'npx' }).warnings).to be_empty
    end
  end

  describe 'fields the transport ignores' do
    it 'flags headers on a stdio server' do
      server = server_for({ 'command' => 'npx', 'headers' => { 'Authorization' => 'Bearer x' } })

      expect(server.warnings.map(&:code)).to include(:ignored_headers)
    end

    it 'flags env on a remote server' do
      server = server_for({ 'type' => 'http', 'url' => 'https://e.com', 'env' => { 'PORT' => '1' } })

      expect(server.warnings.map(&:code)).to include(:ignored_env)
    end
  end

  describe 'credentials stored in the clear' do
    it 'flags a literal token', :aggregate_failures do
      server = server_for({ 'command' => 'npx', 'env' => { 'SHORTCUT_API_TOKEN' => 'sct_ro_abc123' } })
      warning = server.warnings.sole

      expect(warning.code).to eq(:literal_credential)
      expect(warning.suggestion).to include('${SHORTCUT_API_TOKEN}')
    end

    it 'accepts a shell reference in either spelling', :aggregate_failures do
      braced = server_for({ 'command' => 'npx', 'env' => { 'API_KEY' => '${API_KEY}' } })
      bare = server_for({ 'command' => 'npx', 'env' => { 'API_KEY' => '$API_KEY' } })

      expect(braced.warnings).to be_empty
      expect(bare.warnings).to be_empty
    end

    it 'ignores names that do not look like secrets' do
      server = server_for({ 'command' => 'npx', 'env' => { 'LOG_LEVEL' => 'debug' } })

      expect(server.warnings).to be_empty
    end

    it 'flags each offending variable separately' do
      server = server_for(
        { 'command' => 'npx', 'env' => { 'API_KEY' => 'literal', 'DB_PASSWORD' => 'literal', 'LOG_LEVEL' => 'debug' } }
      )

      expect(server.warnings.size).to eq(2)
    end
  end
end
