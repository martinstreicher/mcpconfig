module Ui
  class FlashComponent < ApplicationComponent
    STYLES = {
      'alert' => 'border-rose-300 bg-rose-50 text-rose-900 dark:border-rose-900 dark:bg-rose-950/40 dark:text-rose-200',
      'notice' => 'border-emerald-300 bg-emerald-50 text-emerald-900 ' \
                  'dark:border-emerald-900 dark:bg-emerald-950/40 dark:text-emerald-200'
    }.freeze

    attr_reader :flash

    def initialize(flash:)
      @flash = flash
    end

    def messages
      flash.to_h.slice('alert', 'notice').compact_blank
    end

    def render?
      messages.any?
    end

    def style_for(key)
      STYLES.fetch(key, STYLES['notice'])
    end
  end
end
