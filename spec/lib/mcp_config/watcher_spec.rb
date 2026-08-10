require 'rails_helper'

RSpec.describe McpConfig::Watcher do
  subject(:pattern) { described_class.send(:ignore_pattern) }

  # `match?` is called on the pattern rather than using RSpec's `match` matcher
  # so the value under test is a computed boolean, not a bare literal.
  describe 'the ignore pattern' do
    it 'does not silence the configured user config file' do
      expect(pattern.match?(user_config_path.basename.to_s)).to be(false)
    end

    it 'does not silence a project .mcp.json' do
      expect(pattern.match?('.mcp.json')).to be(false)
    end

    # Without this the watched root is pruned and nothing is ever reported,
    # which is exactly the bug that made watching silently do nothing.
    it 'does not silence the watched root itself' do
      expect(pattern.match?('.')).to be(false)
    end

    it 'silences subdirectories, so a home directory is never walked', :aggregate_failures do
      expect(pattern.match?('node_modules')).to be(true)
      expect(pattern.match?('Library')).to be(true)
      expect(pattern.match?('projects/deep/nested')).to be(true)
    end

    it 'silences unrelated files in a watched directory' do
      expect(pattern.match?('.zshrc')).to be(true)
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
