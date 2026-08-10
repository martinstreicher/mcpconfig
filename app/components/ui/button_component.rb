module Ui
  # Renders a link or a button with the same set of visual variants, so callers
  # do not have to remember which element a given affordance needs.
  class ButtonComponent < ApplicationComponent
    VARIANTS = {
      danger: 'border-rose-300 bg-white text-rose-700 hover:bg-rose-50 ' \
              'dark:border-rose-900 dark:bg-transparent dark:text-rose-300 dark:hover:bg-rose-950/50',
      ghost: 'border-transparent text-slate-600 hover:bg-slate-100 ' \
             'dark:text-slate-300 dark:hover:bg-slate-800',
      primary: 'border-transparent bg-slate-900 text-white hover:bg-slate-700 ' \
               'dark:bg-slate-100 dark:text-slate-900 dark:hover:bg-white',
      secondary: 'border-slate-300 bg-white text-slate-700 hover:bg-slate-50 ' \
                 'dark:border-slate-700 dark:bg-slate-900 dark:text-slate-200 dark:hover:bg-slate-800'
    }.freeze

    attr_reader :href, :label, :options, :variant

    def initialize(label: nil, href: nil, variant: :secondary, **options)
      @href = href
      @label = label
      @options = options
      @variant = variant
    end

    def call
      attributes = options.except(:class)
      body = label || content

      return link_to(body, href, **attributes, class: classes) if href.present?

      tag.button(body, **attributes, class: classes)
    end

    private

    def classes
      [
        'inline-flex items-center gap-1.5 rounded-lg border px-3 py-1.5 text-sm font-medium',
        'transition-colors focus:outline-none focus:ring-2 focus:ring-slate-400 focus:ring-offset-1',
        'dark:focus:ring-offset-slate-900',
        VARIANTS.fetch(variant.to_sym, VARIANTS[:secondary]),
        options[:class]
      ].compact.join(' ')
    end
  end
end
