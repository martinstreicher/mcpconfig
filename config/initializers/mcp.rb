# Settings for the configuration files this app reads and writes.
#
# Everything is overridable through the environment so the app can be pointed at
# a fixture tree during tests, or at a non-standard install during development.
Rails.application.config.mcp = ActiveSupport::OrderedOptions.new

Rails.application.config.mcp.tap do |mcp|
  # ~/.claude.json holds both the user-scoped MCP servers and the per-project
  # ("local" scope) ones under its `projects` key.
  mcp.user_config_path =
    Pathname.new(ENV.fetch('MCP_CONFIG_USER_FILE', File.join(Dir.home, '.claude.json')))

  # Timestamped copies of every file this app overwrites.
  mcp.backup_path =
    Pathname.new(ENV.fetch('MCP_CONFIG_BACKUP_DIR', File.join(Dir.home, '.mcp-config', 'backups')))

  # Backups kept per source file before the oldest are pruned.
  mcp.backup_retention = Integer(ENV.fetch('MCP_CONFIG_BACKUP_RETENTION', 50))

  # Live reload. Disabled during tests so suites do not spawn watcher threads.
  mcp.watch = ActiveModel::Type::Boolean.new.cast(ENV.fetch('MCP_CONFIG_WATCH', !Rails.env.test?))

  # FSEvents/inotify are unavailable in some sandboxes and containers. Polling
  # is slower but always works.
  mcp.force_polling = ActiveModel::Type::Boolean.new.cast(ENV.fetch('MCP_CONFIG_FORCE_POLLING', false))

  # Project directories watched for a .mcp.json. Watching is cheap per directory
  # but not free, so the list is capped.
  mcp.max_watched_projects = Integer(ENV.fetch('MCP_CONFIG_MAX_WATCHED_PROJECTS', 200))

  # Project directories left out of every listing, one .gitignore-style pattern
  # per line. See Mcp::IgnoreList.
  mcp.ignore_file =
    Pathname.new(ENV.fetch('MCP_CONFIG_IGNORE_FILE', File.join(Dir.home, '.mcp-config', 'ignore')))

  # The same patterns, from the environment, for a container or a shared machine
  # that should not have to ship the file. Colon or newline separated.
  mcp.ignore_patterns =
    ENV.fetch('MCP_CONFIG_IGNORE', '').split(/[:\n]/).map(&:strip).compact_blank
end

require Rails.root.join('lib/mcp_config/watcher')

Rails.application.config.after_initialize do
  next unless Rails.application.config.mcp.watch
  next unless McpConfig::Watcher.runnable?

  McpConfig::Watcher.start
end
