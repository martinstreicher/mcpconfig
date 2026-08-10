module Mcp
  # JSON Schema validation for the fragments this app writes.
  #
  # Only the MCP-related parts are described. The surrounding documents allow
  # additional properties on purpose: Claude Code adds keys faster than any
  # schema here could track, and rejecting them would make the file uneditable.
  module Schema
    SERVER = {
      'type' => 'object',
      'properties' => {
        'args' => { 'type' => 'array', 'items' => { 'type' => 'string' } },
        'command' => { 'type' => 'string', 'minLength' => 1 },
        'env' => { 'type' => 'object', 'additionalProperties' => { 'type' => 'string' } },
        'headers' => { 'type' => 'object', 'additionalProperties' => { 'type' => 'string' } },
        'type' => { 'type' => 'string', 'enum' => Server::TRANSPORTS },
        'url' => { 'type' => 'string', 'pattern' => '^https?://' }
      },
      'anyOf' => [
        { 'required' => %w[command] },
        { 'required' => %w[url] }
      ]
    }.freeze

    # Server names are validated by Mcp::Server rather than here: the draft the
    # json-schema gem targets has no propertyNames keyword.
    SERVER_MAP = {
      'type' => 'object',
      'additionalProperties' => SERVER
    }.freeze

    PROJECT_FILE = {
      'type' => 'object',
      'properties' => { 'mcpServers' => SERVER_MAP },
      'additionalProperties' => true
    }.freeze

    USER_FILE = {
      'type' => 'object',
      'properties' => {
        'mcpServers' => SERVER_MAP,
        'projects' => {
          'type' => 'object',
          'additionalProperties' => {
            'type' => 'object',
            'properties' => {
              'disabledMcpjsonServers' => { 'type' => 'array', 'items' => { 'type' => 'string' } },
              'enabledMcpjsonServers' => { 'type' => 'array', 'items' => { 'type' => 'string' } },
              'mcpServers' => SERVER_MAP
            },
            'additionalProperties' => true
          }
        }
      },
      'additionalProperties' => true
    }.freeze

    SCHEMAS = {
      project_file: PROJECT_FILE,
      server: SERVER,
      server_map: SERVER_MAP,
      user_file: USER_FILE
    }.freeze

    # Returns an array of human-readable messages; empty means valid.
    def self.errors_for(name, data)
      JSON::Validator.fully_validate(SCHEMAS.fetch(name), data, errors_as_objects: false)
                     .map { |message| tidy(message) }
    rescue JSON::Schema::ValidationError => e
      [tidy(e.message)]
    end

    def self.tidy(message)
      message.sub(/\s+in schema [0-9a-f-]+\z/, '').sub(/\AThe property /, 'Property ')
    end

    def self.valid?(name, data)
      errors_for(name, data).empty?
    end
  end
end
