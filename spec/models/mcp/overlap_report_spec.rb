require 'rails_helper'

RSpec.describe Mcp::OverlapReport do
  subject(:report) { described_class.new(Mcp::Workspace.new) }

  let(:project) { write_project_directory('alpha') }
  let(:shared)  { stdio_server(args: %w[-y @shortcut/mcp], command: 'npx', env: { 'TOKEN' => 'abc' }) }

  describe 'a project that redefines a user server identically' do
    before do
      write_user_config('mcpServers' => { 'shortcut' => shared }, 'projects' => { project.to_s => {} })
      write_project_config(project, 'mcpServers' => { 'shortcut' => shared })
    end

    it 'reports it as a redundant duplicate rather than a conflict', :aggregate_failures do
      overlap = report.overlaps.sole

      expect(overlap.name).to eq('shortcut')
      expect(overlap.status).to eq(:duplicate)
      expect(overlap.differences).to be_empty
      expect(report.counts).to include(duplicates: 1, overrides: 0, total: 1)
    end

    it 'names the project scope as the one in effect' do
      expect(report.overlaps.sole.winner.scope).to eq(Mcp::Scope.project)
    end
  end

  describe 'a project that redefines a user server differently' do
    let(:overridden) { shared.merge('env' => { 'TOKEN' => 'xyz' }) }

    before do
      write_user_config('mcpServers' => { 'shortcut' => shared }, 'projects' => { project.to_s => {} })
      write_project_config(project, 'mcpServers' => { 'shortcut' => overridden })
    end

    it 'reports an override and says which field diverged', :aggregate_failures do
      overlap = report.overlaps.sole

      expect(overlap.status).to eq(:override)
      expect(overlap.differences.map { |difference| difference[:field] }).to eq(%i[env])
      expect(overlap.summary).to include('Project overrides user')
    end

    it 'marks the user definition as shadowed' do
      expect(report.overlaps.sole.shadowed.map { |server| server.scope.key }).to eq(%w[user])
    end
  end

  describe 'precedence between all three scopes' do
    before do
      write_user_config(
        'mcpServers' => { 'shortcut' => shared },
        'projects' => { project.to_s => { 'mcpServers' => { 'shortcut' => shared.merge('command' => 'bunx') } } }
      )
      write_project_config(project, 'mcpServers' => { 'shortcut' => shared.merge('command' => 'pnpx') })
    end

    it 'puts local ahead of project ahead of user' do
      expect(report.overlaps.sole.servers.map { |server| server.scope.key }).to eq(%w[local project user])
    end
  end

  describe 'the same name in two different projects' do
    let(:other) { write_project_directory('beta') }

    before do
      write_user_config('projects' => { other.to_s => {}, project.to_s => {} })
      write_project_config(project, 'mcpServers' => { 'shortcut' => shared })
      write_project_config(other, 'mcpServers' => { 'shortcut' => shared.merge('command' => 'bunx') })
    end

    it 'is not an overlap, because the two never apply at once' do
      expect(report.overlaps).to be_empty
    end
  end

  describe 'user servers nothing shadows' do
    before do
      write_user_config('mcpServers' => { 'postgres' => shared, 'shortcut' => shared },
                        'projects' => { project.to_s => {} })
      write_project_config(project, 'mcpServers' => { 'shortcut' => shared })
    end

    it 'lists only the untouched ones' do
      expect(report.unshadowed_user_servers.map(&:name)).to eq(%w[postgres])
    end
  end
end
