require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'

abort('The Rails environment is running in production mode!') if Rails.env.production?

require 'rspec/rails'
require 'view_component/test_helpers'

Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |file| require file }

RSpec.configure do |config|
  config.use_active_record = false

  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include ConfigFixtures
  config.include ViewComponent::TestHelpers, type: :component

  # Every example gets its own throwaway config tree, so nothing here can reach
  # the developer's real ~/.claude.json.
  config.around do |example|
    with_isolated_config { example.run }
  end
end
