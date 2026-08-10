# The colour-coded chip that tells you which of the three config locations a
# server came from. Used everywhere a server is shown, so scope is never
# something you have to infer from context.
class ScopeBadgeComponent < ApplicationComponent
  attr_reader :scope, :with_location

  def initialize(scope:, with_location: false)
    @scope = scope
    @with_location = with_location
  end

  def title
    with_location ? "#{scope.location} — #{scope.description}" : scope.description
  end
end
