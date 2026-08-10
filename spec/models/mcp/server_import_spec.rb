require 'rails_helper'

RSpec.describe Mcp::ServerImport do
  subject(:import) { described_class.new(text) }

  describe 'a JSON snippet' do
    context 'with the mcpServers wrapper a README normally shows' do
      let(:text) do
        <<~JSON
          {
            "mcpServers": {
              "postgres": {
                "command": "npx",
                "args": ["-y", "@modelcontextprotocol/server-postgres"],
                "env": { "DATABASE_URL": "postgres://localhost/app" }
              }
            }
          }
        JSON
      end

      it 'reads the name, command, arguments and environment', :aggregate_failures do
        expect(import.error).to be_nil
        expect(import.server.name).to eq('postgres')
        expect(import.server.command).to eq('npx')
        expect(import.server.args).to eq(['-y', '@modelcontextprotocol/server-postgres'])
        expect(import.server.env).to eq('DATABASE_URL' => 'postgres://localhost/app')
      end
    end

    context 'with several servers in one snippet' do
      let(:text) { '{"mcpServers": {"alpha": {"command": "a"}, "beta": {"command": "b"}}}' }

      it 'fills the form in with the first and names the rest', :aggregate_failures do
        expect(import.server.name).to eq('alpha')
        expect(import.extras).to eq(%w[beta])
      end
    end

    context 'with a bare definition and no name' do
      let(:text) { '{"command": "npx", "args": ["-y", "@modelcontextprotocol/server-github"]}' }

      it 'suggests a name from the package', :aggregate_failures do
        expect(import.server.name).to eq('github')
        expect(import.server.command).to eq('npx')
      end
    end

    context 'with a name-keyed definition and no wrapper' do
      let(:text) { '{"filesystem": {"command": "npx", "args": ["-y", "@mcp/fs"]}}' }

      it 'keeps the key as the name' do
        expect(import.server.name).to eq('filesystem')
      end
    end

    context 'with the servers wrapper other editors use' do
      let(:text) { '{"servers": {"sentry": {"url": "https://mcp.sentry.dev/mcp"}}}' }

      it 'reads it as a remote server', :aggregate_failures do
        expect(import.server.name).to eq('sentry')
        expect(import.server.transport).to eq('http')
        expect(import.server.url).to eq('https://mcp.sentry.dev/mcp')
      end
    end

    context 'when the JSON does not parse' do
      let(:text) { '{"mcpServers": {' }

      it 'explains why and imports nothing', :aggregate_failures do
        expect(import.error).to start_with('That is not valid JSON')
        expect(import).not_to be_any
      end
    end

    context 'when the JSON has no definitions in it' do
      let(:text) { '{"theme": "dark"}' }

      it 'says so' do
        expect(import.error).to eq(described_class::NO_DEFINITIONS)
      end
    end
  end

  describe 'a claude mcp add command' do
    context 'with the command after a double dash' do
      let(:text) { 'claude mcp add postgres -- npx -y @modelcontextprotocol/server-postgres' }

      it 'separates the name from the command', :aggregate_failures do
        expect(import.server.name).to eq('postgres')
        expect(import.server.command).to eq('npx')
        expect(import.server.args).to eq(['-y', '@modelcontextprotocol/server-postgres'])
        expect(import.server.transport).to eq('stdio')
      end
    end

    context 'with the command written straight after the name' do
      let(:text) { 'claude mcp add filesystem npx -y @modelcontextprotocol/server-filesystem' }

      it 'still separates them', :aggregate_failures do
        expect(import.server.name).to eq('filesystem')
        expect(import.server.command).to eq('npx')
      end
    end

    context 'with a transport and a URL' do
      let(:text) { 'claude mcp add --transport http linear https://mcp.linear.app/mcp' }

      it 'reads a remote server', :aggregate_failures do
        expect(import.server.name).to eq('linear')
        expect(import.server.transport).to eq('http')
        expect(import.server.url).to eq('https://mcp.linear.app/mcp')
        expect(import.server.command).to be_nil
      end
    end

    context 'with environment, header and scope flags' do
      let(:text) do
        'claude mcp add -s local -e API_KEY=${API_KEY} -H "Authorization: Bearer abc" ' \
          '--transport sse notion https://mcp.notion.com/sse'
      end

      it 'reads each of them', :aggregate_failures do
        expect(import.server.env).to eq('API_KEY' => '${API_KEY}')
        expect(import.server.headers).to eq('Authorization' => 'Bearer abc')
        expect(import.server.transport).to eq('sse')
        expect(import.scope_key).to eq('local')
      end
    end

    context 'with a flag it does not know' do
      let(:text) { 'claude mcp add --verbose postgres -- npx' }

      it 'skips the flag without swallowing the name' do
        expect(import.server.name).to eq('postgres')
      end
    end

    context 'with an add-json payload' do
      let(:text) { %(claude mcp add-json postgres '{"command":"npx","args":["-y","pg"]}') }

      it 'reads the embedded definition', :aggregate_failures do
        expect(import.server.name).to eq('postgres')
        expect(import.server.args).to eq(['-y', 'pg'])
      end
    end

    context 'with a verb it cannot import' do
      let(:text) { 'claude mcp remove postgres' }

      it 'says what it can import' do
        expect(import.error).to eq(described_class::UNSUPPORTED)
      end
    end
  end

  describe 'a bare command line' do
    context 'with a shell prompt and a wrapped line' do
      let(:text) { "$ npx -y \\\n  @modelcontextprotocol/server-filesystem ~/code" }

      it 'strips the prompt and joins the continuation', :aggregate_failures do
        expect(import.server.command).to eq('npx')
        expect(import.server.args).to eq(['-y', '@modelcontextprotocol/server-filesystem', '~/code'])
        expect(import.server.name).to eq('filesystem')
      end
    end

    context 'with a docker invocation' do
      let(:text) { 'docker run -i --rm mcp/github' }

      it 'names it after the image', :aggregate_failures do
        expect(import.server.command).to eq('docker')
        expect(import.server.name).to eq('github')
      end
    end

    context 'with a bare URL' do
      let(:text) { 'https://mcp.sentry.dev/mcp' }

      it 'reads a remote server named after the host', :aggregate_failures do
        expect(import.server.transport).to eq('http')
        expect(import.server.name).to eq('sentry')
      end
    end

    context 'with an unbalanced quote' do
      let(:text) { %(npx -y "@mcp/postgres) }

      it 'explains rather than raising', :aggregate_failures do
        expect(import.error).to start_with('That command could not be read')
        expect(import).not_to be_any
      end
    end
  end

  describe 'nothing at all' do
    let(:text) { "  \n " }

    it 'asks for something to read', :aggregate_failures do
      expect(import.error).to eq(described_class::EMPTY)
      expect(import.server).to be_nil
    end
  end
end
