require 'rails_helper'

RSpec.describe Mcp::Schema do
  describe '.errors_for :server_map' do
    it 'accepts a stdio server' do
      errors = described_class.errors_for(:server_map, 'postgres' => { 'command' => 'npx', 'type' => 'stdio' })

      expect(errors).to be_empty
    end

    it 'accepts a remote server' do
      errors = described_class.errors_for(
        :server_map,
        'sentry' => { 'type' => 'http', 'url' => 'https://mcp.example.com' }
      )

      expect(errors).to be_empty
    end

    it 'rejects a server with neither a command nor a url' do
      errors = described_class.errors_for(:server_map, 'broken' => { 'type' => 'stdio' })

      expect(errors).not_to be_empty
    end

    it 'rejects a transport it does not recognise' do
      errors = described_class.errors_for(:server_map, 'broken' => { 'command' => 'npx', 'type' => 'carrier-pigeon' })

      expect(errors).not_to be_empty
    end

    it 'rejects non-string environment values' do
      errors = described_class.errors_for(:server_map, 'broken' => { 'command' => 'npx', 'env' => { 'PORT' => 5432 } })

      expect(errors).not_to be_empty
    end
  end

  describe '.errors_for :user_file' do
    it 'leaves keys it knows nothing about alone' do
      errors = described_class.errors_for(:user_file, 'someFutureSetting' => { 'nested' => true })

      expect(errors).to be_empty
    end

    it 'still checks the servers nested under a project' do
      errors = described_class.errors_for(
        :user_file,
        'projects' => { '/tmp/app' => { 'mcpServers' => { 'broken' => { 'type' => 'stdio' } } } }
      )

      expect(errors).not_to be_empty
    end
  end
end
