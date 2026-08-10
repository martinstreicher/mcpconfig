module Mcp
  # Raised when a proposed document fails JSON Schema validation. Carries the
  # individual messages so the UI can list them.
  class ValidationError < Error
    attr_reader :messages

    def initialize(messages)
      @messages = Array(messages)

      super(@messages.join('; '))
    end
  end
end
