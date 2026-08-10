module Ui
  class StatComponent < ApplicationComponent
    attr_reader :accent_name, :hint, :href, :label, :value

    def initialize(label:, value:, accent: 'slate', hint: nil, href: nil)
      @accent_name = accent
      @hint = hint
      @href = href
      @label = label
      @value = value
    end
  end
end
