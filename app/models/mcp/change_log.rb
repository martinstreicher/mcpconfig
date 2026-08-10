module Mcp
  # Remembers the most recent change so the UI can show when it last saw the
  # files move, and whether that change came from this app or from outside it.
  #
  # Backed by the cache rather than a class variable so the value survives code
  # reloading in development.
  class ChangeLog
    KEY = 'mcp:last-change'.freeze

    def self.last_change
      Rails.cache.read(KEY)
    end

    def self.last_changed_at
      last_change&.fetch(:at, nil)
    end

    def self.last_paths
      last_change&.fetch(:paths, []) || []
    end

    def self.last_source
      last_change&.fetch(:source, nil)
    end

    def self.record(paths, source: :disk)
      Rails.cache.write(
        KEY,
        { at: Time.current, paths: Array(paths).map(&:to_s), source: source },
        expires_in: 1.day
      )
    end
  end
end
