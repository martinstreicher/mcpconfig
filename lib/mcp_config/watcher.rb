require 'listen'

module McpConfig
  # Watches the config files for changes made outside this app — by the Claude
  # Code CLI, by an editor, by another copy of this app — and pushes a Turbo
  # refresh to every connected browser.
  #
  # This class lives in lib/ and is required rather than autoloaded: it owns a
  # long-lived thread, and a reloadable constant would leave that thread holding
  # a stale class after the first code change in development.
  class Watcher
    PROJECT_CONFIG = '.mcp.json'.freeze

    # The polling adapter's first sweep has nothing to compare against, so it
    # reports every existing file as new. Events this soon after start are the
    # watcher discovering the world, not the world changing.
    WARMUP_SECONDS = 2.0

    class << self
      def mode
        return nil unless running?

        polling? ? :polling : :native
      end

      def polling?
        Rails.application.config.mcp.force_polling
      end

      # Startable when there is at least one directory worth watching.
      def runnable?
        watched_directories.any?
      end

      def running?
        @listener&.processing? || false
      end

      def start
        return @listener if @listener

        directories = watched_directories
        return nil if directories.empty?

        @watched_directories = directories
        @started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        @listener = build_listener(directories)
        @listener.start

        Rails.logger.info(
          "[mcp] watching #{directories.size} #{'directory'.pluralize(directories.size)} for config changes " \
          "(#{polling? ? 'polling' : 'native'})"
        )

        @listener
      end

      def stop
        @listener&.stop
        @listener = nil
      end

      def watched_count
        watched_directories.size
      end

      # The user config file's directory, plus every project directory that
      # currently exists. Capped, because each directory costs a watch.
      def watched_directories
        @watched_directories ||= begin
          limit = Rails.application.config.mcp.max_watched_projects
          directories = [user_config_directory].compact
          directories += project_directories.first(limit)

          directories.uniq.map(&:to_s)
        end
      end

      private

      def build_listener(directories)
        Listen.to(
          *directories,
          force_polling: polling?,
          ignore: [ignore_pattern],
          latency: 0.2,
          wait_for_delay: 0.4
        ) do |modified, added, removed|
          notify(modified + added + removed)
        end
      end

      # Matches everything that is *not* one of the files we care about,
      # including subdirectories — which is what keeps Listen from walking an
      # entire home directory or a node_modules tree. The bare "." is exempted
      # so the watched root itself is not pruned.
      def ignore_pattern
        names = watched_basenames.map { |name| Regexp.escape(name) }.join('|')

        /\A(?!(?:\.|#{names})\z)/
      end

      def notify(paths)
        return if paths.empty?
        return if warming_up?

        Rails.application.executor.wrap { Mcp::ChangeNotifier.call(paths) }
      rescue StandardError => e
        Rails.logger.error("[mcp] watcher callback failed: #{e.class}: #{e.message}")
      end

      def project_directories
        config = Mcp::UserConfig.new
        return [] unless config.exist?

        config.project_paths.map { |path| Pathname.new(path) }.select(&:directory?)
      rescue StandardError => e
        Rails.logger.warn("[mcp] could not enumerate project directories: #{e.message}")
        []
      end

      def user_config_directory
        path = user_config_pathname.dirname

        path.directory? ? path : nil
      end

      def user_config_pathname
        Pathname.new(Rails.application.config.mcp.user_config_path).expand_path
      end

      # The user config filename is configurable, so it is read from settings
      # rather than assumed to be ".claude.json".
      def watched_basenames
        [user_config_pathname.basename.to_s, PROJECT_CONFIG].uniq
      end

      def warming_up?
        return false if @started_at.nil?

        Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started_at < WARMUP_SECONDS
      end
    end
  end
end
