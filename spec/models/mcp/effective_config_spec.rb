require 'rails_helper'

RSpec.describe Mcp::EffectiveConfig do
  subject(:config) { workspace.effective_config(workspace.project(project.to_s)) }

  let(:project)   { write_project_directory('alpha') }
  let(:workspace) { Mcp::Workspace.current }

  def entry(name)
    config.entries.find { |candidate| candidate.name == name }
  end

  describe 'the merge' do
    before do
      write_project_config(project, 'mcpServers' => { 'shared' => stdio_server(command: 'npx'),
                                                      'postgres' => stdio_server(command: 'bunx') })

      write_user_config(
        'mcpServers' => { 'shared' => stdio_server(command: 'npx'),
                          'postgres' => stdio_server(command: 'npx'),
                          'only-user' => stdio_server(command: 'npx') },
        'projects' => { project.to_s => { 'mcpServers' => { 'only-local' => stdio_server(command: 'uvx') } } }
      )
    end

    it 'lists every name from every scope once, in order', :aggregate_failures do
      expect(config.entries.map(&:name)).to eq(%w[only-local only-user postgres shared])
      expect(config.counts[:total]).to eq(4)
    end

    it 'gives an uncontested name the scope it came from', :aggregate_failures do
      expect(entry('only-user').scope).to eq(Mcp::Scope.user)
      expect(entry('only-local').scope).to eq(Mcp::Scope.local)
      expect(entry('only-user')).not_to be_contested
    end

    it 'resolves a contested name to the highest precedence', :aggregate_failures do
      expect(entry('postgres').scope).to eq(Mcp::Scope.project)
      expect(entry('postgres').winner.command).to eq('bunx')
      expect(entry('postgres').shadowed.map(&:command)).to eq(%w[npx])
    end

    it 'separates a real override from a redundant repeat', :aggregate_failures do
      expect(entry('postgres')).to be_override
      expect(entry('postgres').note).to eq('Overrides user')
      expect(entry('shared')).to be_duplicate
      expect(entry('shared').note).to eq('Same as user')
    end

    it 'counts only the overrides as overridden' do
      expect(config.counts[:overridden]).to eq(1)
    end
  end

  describe 'precedence between all three scopes' do
    before do
      write_project_config(project, 'mcpServers' => { 'postgres' => stdio_server(command: 'bunx') })

      write_user_config(
        'mcpServers' => { 'postgres' => stdio_server(command: 'npx') },
        'projects' => { project.to_s => { 'mcpServers' => { 'postgres' => stdio_server(command: 'uvx') } } }
      )
    end

    it 'lets local win over both', :aggregate_failures do
      expect(entry('postgres').scope).to eq(Mcp::Scope.local)
      expect(entry('postgres').note).to eq('Overrides project and user')
    end
  end

  describe 'warnings on the winning definition' do
    before do
      write_user_config(
        'mcpServers' => { 'broken' => stdio_server(command: 'https://example.com/mcp') },
        'projects' => { project.to_s => {} }
      )
    end

    it 'counts them', :aggregate_failures do
      expect(config.counts[:warned]).to eq(1)
      expect(entry('broken').warnings.map(&:code)).to eq([:url_as_command])
    end
  end

  describe 'a project nothing reaches' do
    before { write_user_config('projects' => { project.to_s => {} }) }

    it 'is empty', :aggregate_failures do
      expect(config).not_to be_any
      expect(config.counts[:total]).to be_zero
    end
  end
end
