module Ui
  class BadgeComponent < ApplicationComponent
    attr_reader :accent_name, :label, :title

    def initialize(label: nil, accent: 'slate', title: nil)
      @accent_name = accent
      @label = label
      @title = title
    end

    def call
      tag.span(label || content, class: classes, title: title)
    end

    private

    def classes
      [
        'inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-xs font-medium whitespace-nowrap',
        accent(accent_name, :chip)
      ].join(' ')
    end
  end
end
