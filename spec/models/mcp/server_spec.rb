require 'rails_helper'

RSpec.describe Mcp::Server do
  describe '.from_config' do
    it 'infers a stdio transport from a command' do
      server = described_class.from_config('postgres', { 'command' => 'npx' })

      expect(server.transport).to eq('stdio')
    end

    it 'infers an http transport from a url' do
      server = described_class.from_config('sentry', { 'url' => 'https://example.com/mcp' })

      expect(server.transport).to eq('http')
    end

    it 'keeps keys it does not recognise so they survive a round trip' do
      server = described_class.from_config('odd', { 'command' => 'npx', 'futureOption' => 42 })

      expect(server.to_config).to include('futureOption' => 42)
    end
  end

  describe 'validation' do
    it 'rejects a name with characters Claude Code will not accept' do
      server = described_class.new(command: 'npx', name: 'has spaces')

      expect(server).not_to be_valid
    end

    it 'requires a command for stdio', :aggregate_failures do
      server = described_class.new(name: 'postgres', transport: 'stdio')

      expect(server).not_to be_valid
      expect(server.errors[:command]).to include("can't be blank")
    end

    it 'requires an http or https url for remote transports' do
      server = described_class.new(name: 'sentry', transport: 'http', url: 'ftp://example.com')

      expect(server).not_to be_valid
    end
  end

  describe '#to_config' do
    it 'omits the stdio-only keys for a remote server' do
      server = described_class.new(name: 'sentry', transport: 'http', url: 'https://example.com/mcp')

      expect(server.to_config.keys).to contain_exactly('type', 'url')
    end

    it 'omits empty args and env' do
      server = described_class.new(command: 'npx', name: 'postgres')

      expect(server.to_config.keys).to contain_exactly('command', 'type')
    end
  end

  describe '#fingerprint' do
    it 'matches for two definitions that would run the same thing' do
      one = described_class.from_config('a', { 'command' => 'npx', 'args' => %w[-y pkg] })
      two = described_class.from_config('a', { 'args' => %w[-y pkg], 'command' => 'npx' })

      expect(one.fingerprint).to eq(two.fingerprint)
    end

    it 'differs when the environment differs' do
      one = described_class.from_config('a', { 'command' => 'npx', 'env' => { 'TOKEN' => '1' } })
      two = described_class.from_config('a', { 'command' => 'npx', 'env' => { 'TOKEN' => '2' } })

      expect(one.fingerprint).not_to eq(two.fingerprint)
    end
  end
end
