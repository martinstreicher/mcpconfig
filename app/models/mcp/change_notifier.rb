module Mcp
  # Turns a filesystem event into a Turbo refresh for every open browser.
  #
  # Turbo's page refresh action re-requests whatever page the client is on and
  # morphs the result in, so one broadcast keeps every view live without this
  # class knowing anything about them.
  class ChangeNotifier
    STREAM = 'mcp:config'.freeze

    def self.call(paths)
      paths = Array(paths).uniq
      return if paths.empty?

      ChangeLog.record(paths)
      Rails.logger.info("[mcp] config changed on disk: #{paths.map { |p| File.basename(p) }.uniq.join(', ')}")
      Turbo::StreamsChannel.broadcast_refresh_to(STREAM)
    end
  end
end
