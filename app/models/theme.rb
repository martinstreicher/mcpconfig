# Light, dark, or whatever the operating system says.
#
# The choice is stored in a cookie so the server renders the right class on the
# first paint and the page never flashes the wrong theme.
class Theme
  CHOICES = %w[system light dark].freeze
  DEFAULT = 'system'.freeze

  def self.valid?(choice)
    CHOICES.include?(choice.to_s)
  end
end
