# A read-only, copyable JSON snippet.
class JsonBlockComponent < ApplicationComponent
  attr_reader :label, :value

  def initialize(value:, label: nil)
    @label = label
    @value = value
  end

  def json
    return value if value.is_a?(String)

    JSON.pretty_generate(value)
  rescue JSON::GeneratorError
    value.inspect
  end
end
