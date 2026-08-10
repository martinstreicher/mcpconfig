require 'rails_helper'

RSpec.describe Mcp::Scope do
  describe 'precedence' do
    it 'ranks local above project above user' do
      ordered = described_class.all.sort_by(&:precedence).map(&:key)

      expect(ordered).to eq(%w[user project local])
    end
  end

  describe '#location' do
    # The watcher once assumed the config was always ~/.claude.json and so never
    # watched a configured path. These labels had the same assumption baked in.
    it 'names the configured file rather than the conventional one', :aggregate_failures do
      expect(described_class.user.location).to include(user_config_path.to_s)
      expect(described_class.user.location).not_to include('.claude.json')
    end

    it 'abbreviates a path inside the home directory' do
      allow(Rails.application.config.mcp).to receive(:user_config_path)
        .and_return(Pathname.new(File.join(Dir.home, '.claude.json')))

      expect(described_class.user.location).to eq('~/.claude.json → mcpServers')
    end

    it 'points local scope at the projects key of the same file' do
      expect(described_class.local.location).to include('projects[path].mcpServers')
    end

    it 'points project scope at the project file, not the user file' do
      expect(described_class.project.location).to eq('<project>/.mcp.json → mcpServers')
    end
  end

  describe '#description' do
    it 'names the configured file too' do
      expect(described_class.local.description).to include(user_config_path.to_s)
    end
  end

  describe '.fetch' do
    it 'raises on a scope that does not exist' do
      expect { described_class.fetch('nonsense') }.to raise_error(ArgumentError)
    end
  end
end
