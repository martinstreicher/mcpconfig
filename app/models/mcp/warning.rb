module Mcp
  # A server that is structurally valid but probably not what someone meant.
  #
  # Deliberately separate from ActiveModel validations: a warning never blocks a
  # save. Claude Code will happily store any of these, and this app's job is to
  # point them out, not to refuse to edit a file you already have.
  class Warning
    attr_reader :code, :field, :message, :suggestion

    def initialize(code:, message:, field: nil, suggestion: nil)
      @code = code
      @field = field
      @message = message
      @suggestion = suggestion
    end

    def ==(other)
      other.is_a?(Warning) && other.code == code && other.field == field
    end

    def to_s
      [message, suggestion].compact.join(' ')
    end
  end
end
