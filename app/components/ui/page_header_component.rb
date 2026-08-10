module Ui
  class PageHeaderComponent < ApplicationComponent
    renders_many :actions

    attr_reader :description, :eyebrow, :title

    def initialize(title:, description: nil, eyebrow: nil)
      @description = description
      @eyebrow = eyebrow
      @title = title
    end
  end
end
