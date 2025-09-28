source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.3"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Bundle and transpile JavaScript [https://github.com/rails/jsbundling-rails]
gem "jsbundling-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Bundle and process CSS [https://github.com/rails/cssbundling-rails]
gem "cssbundling-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[windows jruby]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # Test framework and utilities
  gem "rspec-rails", "~> 7.1"
  gem "factory_bot_rails", "~> 6.4"
  gem "faker", "~> 3.5"
  gem "shoulda-matchers", "~> 6.0"
  gem "rails-controller-testing", "~> 1.0"

  # Code quality and performance tools
  gem "simplecov", require: false
  gem "database_cleaner-active_record", "~> 2.2"
  gem "rails_best_practices", require: false
  gem "erb_lint", require: false

  # I18n tools
  gem "i18n-tasks", "~> 1.0"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # N+1 query detection [https://github.com/flyerhzm/bullet]
  gem "bullet", "~> 8.0"

  # Database query analysis and optimization
  gem "prosopite", "~> 1.4"

  # Better error pages [https://github.com/BetterErrors/better_errors]
  gem "better_errors", "~> 2.10"
  gem "binding_of_caller", "~> 1.0"

  # Rails application preloader for faster development
  gem "listen", "~> 3.9"

  # Mail delivery in development
  gem "letter_opener", "~> 1.10"

  # Annotate models with schema information (Rails 8 compatible fork)
  gem "annotaterb", "~> 4.19"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"

  # Accessibility testing
  gem "axe-core-rspec", "~> 4.9"
  gem "axe-core-capybara", "~> 4.9"
end

gem "devise", "~> 4.9"
gem "pundit", "~> 2.3"
gem "rolify", "~> 6.0"
gem "pg_search", "~> 2.3"
gem "acts_as_tenant", "~> 1.0"
gem "mission_control-jobs", "~> 1.1"
gem "metainspector", "~> 5.16"
gem "feedjira", "~> 4.0"
gem "tailwindcss-rails", "~> 4.3"
gem "meta-tags", "~> 2.22"
gem "strong_migrations", "~> 2.0"
gem "draper", "~> 4.0"
