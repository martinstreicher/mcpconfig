module Mcp
  # A JSON file on disk, read defensively and written safely.
  #
  # Writes are backed up, validated, then swapped into place through a temp file
  # in the same directory so a crash mid-write can never truncate the original.
  class JsonDocument
    class ParseError < StandardError; end

    DEFAULT_MODE = 0o600

    attr_reader :path

    def initialize(path)
      @path = Pathname.new(path).expand_path
    end

    def data
      return @data if defined?(@data)

      @data = parse
    end

    def digest
      return nil unless exist?

      Digest::SHA256.hexdigest(raw)
    end

    def exist?
      path.file?
    end

    def mtime
      return nil unless exist?

      path.mtime
    end

    # Nil when the file is absent or parses cleanly, otherwise the parser
    # message. Callers use this to show a broken file instead of blowing up.
    def parse_error
      data
      @parse_error
    rescue ParseError => e
      e.message
    end

    def raw
      return '' unless exist?

      path.read
    end

    def readable?
      exist? && path.readable?
    end

    def reload
      remove_instance_variable(:@data) if defined?(@data)
      @parse_error = nil

      self
    end

    def size
      return 0 unless exist?

      path.size
    end

    def valid?
      parse_error.nil?
    end

    # Replaces the whole document. The caller always passes the complete hash so
    # keys this app does not understand survive untouched.
    def write(new_data, backup: true)
      contents = "#{JSON.pretty_generate(new_data)}\n"
      Backup.create(self) if backup && exist?

      path.dirname.mkpath
      write_atomically(contents)
      reload

      contents
    end

    private

    def parse
      return {} unless exist?

      contents = raw
      return {} if contents.blank?

      parsed = JSON.parse(contents)
      raise ParseError, 'expected the file to contain a JSON object' unless parsed.is_a?(Hash)

      parsed
    rescue JSON::ParserError => e
      @parse_error = e.message
      {}
    end

    def write_atomically(contents)
      mode = exist? ? path.stat.mode & 0o7777 : DEFAULT_MODE

      temp = path.dirname.join(".#{path.basename}.#{Process.pid}.#{SecureRandom.hex(4)}.tmp")
      temp.write(contents)
      temp.chmod(mode)
      temp.rename(path.to_s)
    ensure
      temp&.delete if temp&.exist?
    end
  end
end
