module Ui
  # A titled panel. The workhorse container for everything on a page.
  class CardComponent < ApplicationComponent
    renders_many :actions
    renders_one :footer

    attr_reader :accent_name, :subtitle, :title

    def initialize(title: nil, subtitle: nil, accent: 'slate', padded: true)
      @accent_name = accent
      @padded = padded
      @subtitle = subtitle
      @title = title
    end

    def body_classes
      padded? ? 'p-5' : ''
    end

    def header?
      title.present? || actions?
    end

    def padded?
      @padded
    end

    def wrapper_classes
      [
        'rounded-xl border bg-white shadow-xs dark:bg-slate-900/60',
        accent(accent_name, :border)
      ].join(' ')
    end
  end
end
