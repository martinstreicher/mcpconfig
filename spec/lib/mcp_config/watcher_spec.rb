require 'rails_helper'

RSpec.describe McpConfig::Watcher do
  subject(:pattern) { described_class.send(:ignore_pattern) }

  describe 'the ignore pattern' do
    it 'does not silence the configured user config file' do
      expect(user_config_path.basename.to_s).not_to match(pattern)
    end

    it 'does not silence a project .mcp.json' do
      expect('.mcp.json').not_to match(pattern)
    end

    # Without this the watched root is pruned and nothing is ever reported,
    # which is exactly the bug that made watching silently do nothing.
    it 'does not silence the watched root itself' do
      expect('.').not_to match(pattern)
    end

    it 'silences subdirectories, so a home directory is never walked', :aggregate_failures do
      expect('node_modules').to match(pattern)
      expect('Library').to match(pattern)
      expect('projects/deep/nested').to match(pattern)
    end

    it 'silences unrelated files in a watched directory' do
      expect('.zshrc').to match(pattern)
    end
  end

  describe '.watched_directories' do
    it 'includes the directory holding the user config' do
      described_class.instance_variable_set(:@watched_directories, nil)

      expect(described_class.watched_directories).to include(user_config_path.dirname.to_s)
    ensure
      described_class.instance_variable_set(:@watched_directories, nil)
    end
  end
end
