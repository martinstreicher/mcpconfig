module Ui
  class EmptyStateComponent < ApplicationComponent
    attr_reader :description, :title

    def initialize(title:, description: nil)
      @description = description
      @title = title
    end
  end
end
