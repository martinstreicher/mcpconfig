module Mcp
  # A timestamped copy of a config file, taken immediately before this app
  # overwrites it.
  #
  # The original bytes are stored verbatim alongside a little metadata, so a
  # restore reproduces the file exactly rather than a re-serialised guess at it.
  class Backup
    FORMAT_VERSION = 1
    TIMESTAMP_FORMAT = '%Y%m%d-%H%M%S-%L'.freeze

    def self.all(source_path: nil)
      return [] unless root.directory?

      backups = root.glob('*.json').filter_map { |file| load(file) }
      backups = backups.select { |backup| backup.source_path.to_s == source_path.to_s } if source_path

      backups.sort_by(&:created_at).reverse
    end

    def self.create(document)
      return nil unless document.exist?

      root.mkpath
      backup = new(
        contents: document.raw,
        created_at: Time.current,
        path: root.join(filename_for(document.path)),
        source_path: document.path
      )
      backup.save
      prune(document.path)

      backup
    end

    def self.filename_for(source_path)
      "#{slug(source_path)}--#{Time.current.strftime(TIMESTAMP_FORMAT)}.json"
    end

    def self.find(id)
      all.find { |backup| backup.id == id }
    end

    def self.load(file)
      payload = JSON.parse(file.read)
      return nil unless payload['version'] == FORMAT_VERSION

      new(
        contents: payload['contents'],
        created_at: Time.zone.parse(payload['created_at']),
        path: file,
        source_path: Pathname.new(payload['source_path'])
      )
    rescue JSON::ParserError, Errno::ENOENT
      nil
    end

    def self.prune(source_path)
      keep = Rails.application.config.mcp.backup_retention

      all(source_path: source_path).drop(keep).each { |backup| backup.path.delete }
    end

    def self.root
      Pathname.new(Rails.application.config.mcp.backup_path).expand_path
    end

    # Filesystem-safe stand-in for the full source path, so backups of two files
    # with the same basename never collide.
    def self.slug(source_path)
      source_path.to_s.delete_prefix(Dir.home).gsub(/[^a-zA-Z0-9]+/, '-').delete_prefix('-').presence || 'config'
    end

    attr_reader :contents, :created_at, :path, :source_path

    def initialize(contents:, created_at:, path:, source_path:)
      @contents = contents
      @created_at = created_at
      @path = Pathname.new(path)
      @source_path = Pathname.new(source_path)
    end

    def byte_size
      contents.to_s.bytesize
    end

    def id
      path.basename('.json').to_s
    end

    def parsed_contents
      JSON.parse(contents)
    rescue JSON::ParserError
      nil
    end

    # Puts the captured bytes back, taking a backup of the current file first so
    # a restore is itself undoable.
    def restore
      document = JsonDocument.new(source_path)
      self.class.create(document)

      source_path.dirname.mkpath
      source_path.write(contents)

      self
    end

    def save
      path.dirname.mkpath
      path.write(JSON.pretty_generate(to_payload))
      path.chmod(0o600)

      self
    end

    def server_names
      parsed = parsed_contents
      return [] unless parsed.is_a?(Hash)

      names = parsed.fetch('mcpServers', {}).keys
      names += parsed.fetch('projects', {}).values.flat_map { |entry| entry.fetch('mcpServers', {}).keys }

      names.uniq.sort
    end

    def to_param
      id
    end

    def to_payload
      {
        'contents' => contents,
        'created_at' => created_at.iso8601(3),
        'source_path' => source_path.to_s,
        'version' => FORMAT_VERSION
      }
    end
  end
end
