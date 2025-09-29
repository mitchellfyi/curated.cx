# frozen_string_literal: true

require 'capybara/rails'
require 'capybara/rspec'

# Configure Capybara for system tests
Capybara.configure do |config|
  # Always use Chromium for all system tests
  config.default_driver = :selenium_chrome_headless
  config.javascript_driver = :selenium_chrome_headless
  config.default_max_wait_time = 10
  config.server = :puma, { Silent: true, Threads: "0:1" }
  config.server_port = 0  # Let Capybara choose an available port automatically

  # Ensure we always use Chromium, never rack-test
  config.always_include_port = true
end

# Ensure system tests go through the full Rails middleware stack
RSpec.configure do |config|
  config.before(:each, type: :system) do
    # Always use Chromium for system tests - never rack-test
    # This ensures we test the full Rails middleware stack including tenant resolution
    driven_by :selenium_chrome_headless
  end
end
