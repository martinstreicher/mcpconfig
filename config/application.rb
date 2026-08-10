require_relative 'boot'

require 'rails'
# Pick the frameworks you want:
require 'active_model/railtie'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'action_cable/engine'
require 'rails/test_unit/railtie'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module McpConfig
  class Application < Rails::Application
    config.load_defaults 8.1

    # lib/mcp_config holds the file watcher, which is required explicitly from an
    # initializer because it owns a thread that must outlive code reloading.
    config.autoload_lib(ignore: %w[assets mcp_config tasks])

    # This app has no database: every piece of state lives in the JSON files it
    # edits. Generators that assume Active Record would only create dead files.
    config.generators do |g|
      g.helper false
      g.system_tests nil
    end
  end
end
