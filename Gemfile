source 'https://rubygems.org'

gem 'bootsnap', require: false
gem 'importmap-rails'

# json 3.0 dropped the positional options hash from JSON.parse, which
# ActiveSupport::JSON.decode still passes. That breaks every signed or encrypted
# message Rails reads back, the session cookie included. Unpin once Rails ships
# a version that calls JSON.parse with keywords.
gem 'json', '< 3'

gem 'json-schema'
gem 'listen'
gem 'propshaft'
gem 'puma', '>= 5.0'
gem 'rails', '~> 8.1.3', '>= 8.1.3.1'
gem 'stimulus-rails'
gem 'tailwindcss-rails'
gem 'turbo-rails'
gem 'tzinfo-data', platforms: %i[windows jruby]
gem 'view_component'

group :development, :test do
  gem 'debug', platforms: %i[mri windows], require: 'debug/prelude'
  gem 'rspec-rails'
  gem 'rubocop', require: false
  gem 'rubocop-ordered_methods', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false
end

group :development do
  gem 'web-console'
end

group :test do
  gem 'capybara'
  gem 'rails-controller-testing'
end
