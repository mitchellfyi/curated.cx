# frozen_string_literal: true

require 'capybara/rails'
require 'capybara/rspec'

# Configure Capybara for system tests
Capybara.configure do |config|
  config.default_driver = :selenium_chrome_headless
  config.javascript_driver = :selenium_chrome_headless
  config.default_max_wait_time = 5
  config.server = :puma, { Silent: true }
  config.server_port = 3001  # Use a different port to avoid conflicts
end

# Ensure system tests go through the full Rails middleware stack
RSpec.configure do |config|
  config.before(:each, type: :system) do
    # Ensure the tenant resolver middleware is used
    # This is important for multi-tenant applications
    driven_by :selenium_chrome_headless
  end
end
