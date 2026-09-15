source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "4.0.5"

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem "rails", "8.1.3"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.5"
# Use Puma as the app server
gem "puma", "~> 7.2"
# Use SCSS for stylesheets
gem "sass-rails", ">= 6"
# Transpile app-like JavaScript. Read more: https://github.com/rails/webpacker
gem "webpacker", "~> 5.4"
# Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
gem "turbolinks", "~> 5"
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem "jbuilder", "~> 2.15"
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 4.0'
# Use Active Model has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Active Storage variant
gem "image_processing", "~> 1.2"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", ">= 1.18.3", require: false

group :development, :test do
  # Use the debugger supported by current Ruby versions.
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
end

group :development do
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem "web-console", ">= 4.2"
  gem "listen", "~> 3.10"
end

group :test do
  # Adds support for Capybara system testing and selenium driver
  gem "capybara", ">= 3.40"
  gem "selenium-webdriver", ">= 4.21"
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[windows jruby]

gem "capistrano", "~> 3.20", group: :development

gem "capistrano-rails", "~> 1.7", group: :development
gem "capistrano-rbenv", "~> 2.2", group: :development
gem "capistrano3-puma", "~> 8.1", group: :development
