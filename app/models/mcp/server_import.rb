require 'shellwords'

module Mcp
  # Turns pasted text into server definitions.
  #
  # Nobody composes a server from nothing: they copy the JSON snippet out of a
  # README, or the `claude mcp add` line that same README suggests, and then
  # retype it a field at a time. All three shapes — a JSON snippet, a CLI
  # invocation, and a bare command line — are parsed here so the add form can be
  # filled in from the clipboard instead.
  #
  # Nothing is written from this. The result only populates a form, which is why
  # a best-effort guess at a missing name is better than a refusal.
  class ServerImport
    ADD_VERBS = %w[add add-json].freeze

    # Keys that mark a hash as one server definition rather than a collection of
    # them keyed by name.
    DEFINITION_KEYS = %w[args command env headers type url].freeze

    EMPTY = 'Paste a JSON snippet, a `claude mcp add` command, or a command line first.'.freeze

    # Every flag that is understood, and what it sets. A flag that is not in here
    # is skipped on its own rather than taking the word after it, so one this does
    # not know cannot swallow the server name that follows it.
    FLAGS = {
      '--env' => :env,
      '-e' => :env,
      '--header' => :headers,
      '-H' => :headers,
      '--scope' => :scope,
      '-s' => :scope,
      '--transport' => :transport,
      '-t' => :transport
    }.freeze

    # Host labels that say nothing about which service a URL belongs to.
    GENERIC_LABELS = %w[api mcp server www].freeze

    # `npx -y @modelcontextprotocol/server-github` is a github server, not a
    # server-github one.
    NAME_NOISE = /\A(?:mcp[-_]|server[-_])+|(?:[-_]mcp|[-_]server)+\z/

    NO_DEFINITIONS = 'That JSON has no MCP server definitions in it.'.freeze

    UNSUPPORTED = 'Only `claude mcp add` and `claude mcp add-json` can be imported.'.freeze

    WRAPPER_KEYS = %w[mcpServers servers].freeze

    attr_reader :error, :scope_key, :servers, :text

    def initialize(text)
      @scope_key = nil
      @servers = []
      @text = text.to_s.strip

      if @text.blank?
        @error = EMPTY
      else
        import
      end
    end

    def any?
      servers.any?
    end

    # Names beyond the one the form was filled in with. Pasting a README that
    # documents three servers is normal; dropping two of them silently is not.
    def extras
      servers.drop(1).map(&:name)
    end

    def server
      servers.first
    end

    private

    def apply_flag(flag, value, options)
      return if value.blank?

      case FLAGS[flag]
      when :env then merge_pair(options[:env], value)
      when :headers then merge_pair(options[:headers], value)
      when :scope then remember_scope(value)
      when :transport then remember_transport(value, options)
      end
    end

    def build(name, config)
      server = Server.from_config(name.to_s, config)
      server.name = suggested_name(server) if name.blank?

      server
    end

    def build_from_words(words, name: nil, env: {}, headers: {}, transport: nil)
      remote = remote?(words, transport)

      server = Server.new(
        args: remote ? [] : words.drop(1),
        command: (words.first unless remote),
        env: env,
        headers: headers,
        name: name.presence,
        transport: transport.presence || (remote ? 'http' : 'stdio'),
        url: (words.first if remote)
      )

      server.name = suggested_name(server) if name.blank?

      server
    end

    # Splits `add` arguments into the flags it understands and the positional
    # words left over, which are the name and then either a URL or a command.
    def command_options(argv)
      options = { env: {}, headers: {}, positional: [], tail: [], transport: nil }
      words = argv.dup

      until words.empty?
        word = words.shift

        if word == '--'
          options[:tail] = words
          break
        end

        unless word.start_with?('-')
          options[:positional] << word
          next
        end

        flag, inline = word.split('=', 2)
        apply_flag(flag, inline || (words.shift if FLAGS.key?(flag)), options)
      end

      options
    end

    # Pastes arrive with a shell prompt in front, and long ones arrive wrapped
    # with backslash continuations.
    def command_text
      text.gsub("\\\n", ' ').sub(/\A[$>]\s+/, '').strip
    end

    def definition?(value)
      value.is_a?(Hash) && DEFINITION_KEYS.any? { |key| value.key?(key) }
    end

    # Either a wrapper keyed by server name, a single bare definition, or a hash
    # whose values happen to be definitions.
    def definitions_in(data)
      return {} unless data.is_a?(Hash)

      wrapper = data.values_at(*WRAPPER_KEYS).compact.first
      return wrapper if wrapper.is_a?(Hash)
      return { nil => data } if definition?(data)

      data.select { |_name, config| definition?(config) }
    end

    def host_label(url)
      labels = URI.parse(url.to_s).host.to_s.split('.')
      meaningful = labels[0..-2].to_a.reject { |label| GENERIC_LABELS.include?(label) }

      (meaningful.last || labels.first).to_s
    rescue URI::InvalidURIError
      ''
    end

    def import
      return import_json if text.start_with?('{')

      import_command
    end

    def import_add(argv)
      options = command_options(argv)
      name = options[:positional].shift
      words = options[:tail].presence || options[:positional]

      return @error = 'That command names no server to add.' if words.empty? && name.blank?

      @servers = [
        build_from_words(
          words,
          env: options[:env],
          headers: options[:headers],
          name: name,
          transport: options[:transport]
        )
      ]
    end

    def import_add_json(argv)
      name, json = command_options(argv)[:positional]

      return @error = 'That add-json command has no JSON in it.' if json.blank?

      @servers = [build(name, JSON.parse(json))]
    rescue JSON::ParserError => e
      @error = "The JSON in that command is not valid — #{e.message.truncate(120)}"
    end

    def import_cli(words)
      argv = words.drop(1)
      argv = argv.drop(1) if argv.first == 'mcp'
      verb = argv.shift

      return @error = UNSUPPORTED unless ADD_VERBS.include?(verb)
      return import_add_json(argv) if verb == 'add-json'

      import_add(argv)
    end

    def import_command
      words = Shellwords.split(command_text)

      return @error = EMPTY if words.empty?
      return import_cli(words) if words.first == 'claude'

      @servers = [build_from_words(words)]
    rescue ArgumentError => e
      @error = "That command could not be read — #{e.message}"
    end

    def import_json
      definitions = definitions_in(JSON.parse(text))

      return @error = NO_DEFINITIONS if definitions.blank?

      @servers = definitions.map { |name, config| build(name, config) }
    rescue JSON::ParserError => e
      @error = "That is not valid JSON — #{e.message.truncate(120)}"
    end

    # A path argument is the server's configuration rather than its identity, so
    # it only gets to name the server when there is nothing else left.
    def last_identifier(words)
      words.reject { |word| path_like?(word) }.last || words.last
    end

    # Environment pairs are written NAME=value and headers `Name: value`, and
    # both arrive quoted as a single word.
    def merge_pair(target, text)
      key, value = text.split(/\s*[:=]\s*/, 2)
      return if key.blank? || value.blank?

      target[key.strip] = value.strip
    end

    # The package or image that implements the server names it far better than the
    # command does, since that is usually just npx, uvx or docker.
    def package_label(server)
      File.basename(package_word(server).to_s).sub(/\.[a-z]+\z/i, '')
    end

    def package_like?(word)
      !path_like?(word) && word.match?(%r{[@/]})
    end

    def package_word(server)
      words = plain_words(server.args)

      words.find { |word| package_like?(word) } || last_identifier(words) || server.command
    end

    def path_like?(word)
      word.start_with?('/', '~', '.')
    end

    def plain_words(args)
      args.reject { |arg| arg.start_with?('-') || arg.include?('=') }
    end

    def remember_scope(value)
      @scope_key = value if Scope.exists?(value)
    end

    def remember_transport(value, options)
      options[:transport] = value if Server::TRANSPORTS.include?(value)
    end

    def remote?(words, transport)
      return Server::REMOTE_TRANSPORTS.include?(transport) if transport.present?

      words.first.to_s.match?(Server::URL_LIKE)
    end

    # Trims the parts of a package or host name that every MCP server shares,
    # unless doing so leaves nothing worth keeping.
    def sanitise(candidate)
      trimmed = candidate.to_s.gsub(NAME_NOISE, '')
      trimmed = candidate.to_s if trimmed.length < 3

      trimmed.gsub(/[^a-zA-Z0-9_.-]/, '-')
             .sub(/\A[^a-zA-Z0-9]+/, '')
             .sub(/[^a-zA-Z0-9]+\z/, '')
             .presence || 'server'
    end

    def suggested_name(server)
      sanitise(server.remote? ? host_label(server.url) : package_label(server))
    end
  end
end
