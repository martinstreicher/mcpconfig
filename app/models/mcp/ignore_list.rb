module Mcp
  # Project directories to leave out of every listing.
  #
  # Patterns are written the way .gitignore writes them: one per line, # for a
  # comment, * and ? and [abc] inside a single directory name, ** across names, a
  # leading ! to put something back, and the last matching line winning. Ignoring
  # a directory ignores everything beneath it.
  #
  # Two deliberate departures from git, both forced by the subject matter:
  #
  # Anchoring. Git measures a pattern from the repository root. There is no root
  # here, only absolute paths from all over a filesystem, so a pattern holding a
  # slash is matched against the end of the path unless it starts with / or ~/,
  # and a pattern with no slash matches any single directory name — which is what
  # .gitignore does with a bare name anyway.
  #
  # Case. Matching ignores case, because this app's home is macOS, where a path
  # differing only in case is the same directory. Git would compare exactly.
  #
  # Nothing here writes to a config file. An ignored project keeps its servers and
  # Claude Code keeps loading them; it is this app's listings that look away.
  class IgnoreList
    # Written into a file this app creates, so the syntax is discoverable from the
    # file itself and not only from here.
    HEADER = [
      '# Project directories MCP Config leaves out of its listings.',
      '#',
      '# One pattern per line, in .gitignore syntax: * and ? and [abc] match within',
      '# a single directory name, ** matches across them, a leading ! puts something',
      '# back, and the last line that matches a path decides. A pattern with no',
      '# slash matches any directory of that name, at any depth.',
      '#',
      '# Examples:',
      '#   node_modules          any directory named node_modules',
      '#   ~/scratch             one directory, and everything under it',
      '#   ~/code/*/vendor       vendor inside any single directory under ~/code',
      '#   ~/experiments/**      everything below ~/experiments',
      '#   !~/scratch/keep-me    an exception to a line above',
      ''
    ].freeze

    MODE = 0o600

    attr_reader :path

    def self.current
      new
    end

    def initialize(path: nil, extra_patterns: nil)
      settings = Rails.application.config.mcp

      @path = Pathname.new(path || settings.ignore_file).expand_path
      @extra_patterns = Array(extra_patterns || settings.ignore_patterns).map(&:to_s)
    end

    # Appends a pattern, leaving the rest of the file — its comments, its order —
    # untouched. False when the pattern is already in there.
    def add(pattern)
      pattern = pattern.to_s.strip
      return false if pattern.blank?
      return false if file_patterns.include?(pattern)

      write(exist? ? file_lines + [pattern] : HEADER + [pattern])
      true
    end

    def any?
      rules.any?
    end

    # Patterns supplied through the environment. They apply like any other but
    # cannot be edited here, since this app does not own the environment.
    def environment_patterns
      extra_patterns.filter_map { |pattern| meaningful(pattern) }
    end

    def exist?
      path.file?
    end

    # Every line of the file as written, comments and blanks included.
    def file_lines
      return [] unless exist?

      path.read.split("\n")
    rescue SystemCallError
      []
    end

    # The patterns the file contributes, comments and blanks dropped.
    def file_patterns
      file_lines.filter_map { |line| meaningful(line) }
    end

    def ignore?(candidate)
      candidate = candidate.to_s
      return false if candidate.blank?

      # The last match decides, so the search runs backwards and stops at the
      # first rule that has anything to say.
      rule = rules.reverse_each.find { |current_rule| current_rule.matches?(candidate) }

      rule.present? && !rule.negated
    end

    def ignored(paths)
      paths.select { |candidate| ignore?(candidate) }
    end

    def keep(paths)
      paths.reject { |candidate| ignore?(candidate) }
    end

    # The effective patterns, file and environment together, in the order applied.
    def patterns
      rules.map(&:to_s)
    end

    # Removes a pattern by its exact text. False when no line said that.
    def remove(pattern)
      pattern = pattern.to_s.strip
      remaining = file_lines.reject { |line| line.strip == pattern }
      return false if remaining.size == file_lines.size

      write(remaining)
      true
    end

    # Puts a directory back. Dropping the line that named it is enough when it was
    # ignored outright; when a wildcard caught it the only way back is an
    # exception, which is what .gitignore's ! is for.
    def unignore(candidate)
      candidate = candidate.to_s
      dropped = drop_literal_lines(candidate)

      return true if dropped && !ignore?(candidate)
      return false unless ignore?(candidate)

      add("!#{candidate}")
    end

    private

    attr_reader :extra_patterns

    # Drops the lines that name this directory outright, as typed or with ~
    # expanded. Wildcard lines are left alone: they are holding other projects.
    def drop_literal_lines(candidate)
      remaining = file_lines.reject { |line| names_directly?(line, candidate) }
      return false if remaining.size == file_lines.size

      write(remaining)
      true
    end

    # Blank lines and comments carry no rule.
    def meaningful(line)
      stripped = line.strip
      return nil if stripped.blank?
      return nil if stripped.start_with?('#')

      stripped
    end

    def names_directly?(line, candidate)
      pattern = meaningful(line)
      return false if pattern.blank?

      rule = Rule.new(pattern)
      return false if rule.negated || !rule.literal?

      rule.literal_path.casecmp?(candidate)
    end

    def reset
      remove_instance_variable(:@rules) if defined?(@rules)
    end

    def rules
      @rules ||= (file_patterns + environment_patterns).map { |pattern| Rule.new(pattern) }
    end

    def write(lines)
      path.dirname.mkpath

      temp = path.dirname.join(".#{path.basename}.#{Process.pid}.#{SecureRandom.hex(4)}.tmp")
      temp.write(lines.map { |line| "#{line}\n" }.join)
      temp.chmod(MODE)
      temp.rename(path.to_s)

      reset
    ensure
      temp&.delete if temp&.exist?
    end
  end
end
