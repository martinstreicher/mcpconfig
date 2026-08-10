module Layout
  # Shows whether the file watcher is running and when it last saw the config
  # move — so a stale page is obvious rather than silently wrong.
  class LiveStatusComponent < ApplicationComponent
    def last_change_source
      Mcp::ChangeLog.last_source
    end

    def last_changed_at
      Mcp::ChangeLog.last_changed_at
    end

    def mode
      McpConfig::Watcher.mode
    end

    def running?
      McpConfig::Watcher.running?
    end

    def title
      return 'File watching is off. Reload to see changes made outside this app.' unless running?

      "Watching #{McpConfig::Watcher.watched_count} directories (#{mode})"
    end

    def watched_count
      McpConfig::Watcher.watched_count
    end
  end
end
