module Mcp
  class IgnoreList
    # One line of the ignore file, compiled to something that can be asked about a
    # path. See Mcp::IgnoreList for the syntax and for where it parts company with
    # git.
    class Rule
      # One glob token, longest spelling first so ** is never read as two *. The
      # final "." is the fallback: any other character stands for itself.
      TOKEN = %r{\*\*/|\*\*|\*|\?|\[!?\]?[^\]]*\]|\\.|.}

      # Characters that make a pattern a pattern rather than a name.
      WILDCARDS = /[*?\[\]\\]/

      attr_reader :negated, :pattern

      def self.expand_home(pattern)
        return pattern unless pattern == '~' || pattern.start_with?('~/')

        File.join(Dir.home, pattern.delete_prefix('~').delete_prefix('/'))
      end

      # Glob to Regexp source, a token at a time, which is what keeps * inside a
      # single directory name while letting ** cross between them.
      def self.translate(glob)
        glob.scan(TOKEN).map { |token| translate_token(token) }.join
      end

      # A bracket expression, with .gitignore's ! spelled the way Regexp wants it.
      def self.translate_bracket(token)
        inner = token[1..-2]

        return "[^#{inner[1..]}]" if inner.start_with?('!', '^')

        "[#{inner}]"
      end

      # Everything that is not a wildcard: a bracket expression, a backslash
      # quoting the character after it, or an ordinary character.
      def self.translate_literal(token)
        return translate_bracket(token) if token.start_with?('[') && token.end_with?(']')
        return Regexp.escape(token[1]) if token.start_with?('\\') && token.length == 2

        Regexp.escape(token)
      end

      def self.translate_token(token)
        case token
        when '**/' then '(?:[^/]+/)*'
        when '**' then '.*'
        when '*' then '[^/]*'
        when '?' then '[^/]'
        else translate_literal(token)
        end
      end

      def initialize(line)
        @negated = line.start_with?('!')
        @pattern = strip_escape(@negated ? line[1..] : line)
        @matcher = build_matcher
      end

      # True when the pattern holds no wildcards, so it names exactly one
      # directory rather than a class of them.
      def literal?
        !pattern.match?(WILDCARDS)
      end

      # The single directory a literal pattern names, absolute.
      def literal_path
        return nil unless literal?

        self.class.expand_home(pattern.delete_suffix('/'))
      end

      def matches?(path)
        @matcher.match?(path.to_s)
      end

      def to_s
        negated ? "!#{pattern}" : pattern
      end

      private

      # A trailing slash is dropped because every entry here is a directory. The
      # prefix is where anchoring is decided: an absolute pattern is measured from
      # the start of the path, anything else from a directory boundary. The suffix
      # is what makes ignoring a directory ignore its contents too.
      def build_matcher
        body = self.class.expand_home(pattern.delete_suffix('/'))
        prefix = body.start_with?('/') ? '\A/' : '\A(?:.*/)?'

        Regexp.new("#{prefix}#{self.class.translate(body.delete_prefix('/'))}(?:/.*)?\\z", Regexp::IGNORECASE)
      rescue RegexpError
        # A pattern that will not compile is treated as one that never matches, so
        # a single bad line cannot hide every project.
        /(?!)/
      end

      # A leading ! or # is escaped in .gitignore to mean the character itself.
      def strip_escape(pattern)
        pattern.start_with?('\!', '\#') ? pattern[1..] : pattern
      end
    end
  end
end
