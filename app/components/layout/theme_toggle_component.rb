module Layout
  # Three-way theme switch. Rendered as a form so it works before Stimulus loads;
  # the theme controller intercepts it to apply the change without a round trip.
  class ThemeToggleComponent < ApplicationComponent
    LABELS = { 'dark' => 'Dark', 'light' => 'Light', 'system' => 'Auto' }.freeze

    attr_reader :current

    def initialize(current:)
      @current = current
    end

    def button_classes(choice)
      base = 'rounded-md px-2 py-1 text-xs font-medium transition-colors'

      if choice == current
        "#{base} bg-white text-slate-900 shadow-xs dark:bg-slate-700 dark:text-slate-50"
      else
        "#{base} text-slate-500 hover:text-slate-800 dark:text-slate-400 dark:hover:text-slate-100"
      end
    end

    def choices
      Theme::CHOICES
    end

    def label_for(choice)
      LABELS.fetch(choice, choice.titleize)
    end
  end
end
