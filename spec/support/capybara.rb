# frozen_string_literal: true

require 'capybara/rails'
require 'capybara/rspec'

# Configure Capybara for system tests
Capybara.configure do |config|
  # Use rack-test for system tests to avoid browser dependencies
  config.default_driver = :rack_test
  config.javascript_driver = :rack_test
  config.default_max_wait_time = 10
  config.server = :puma, { Silent: true, Threads: "0:1" }
  config.server_port = 0  # Let Capybara choose an available port automatically

  # Ensure we always use rack-test for now
  config.always_include_port = true
end

# Ensure system tests go through the full Rails middleware stack
RSpec.configure do |config|
  config.before(:each, type: :system) do
    # Use rack-test for system tests to avoid browser dependencies
    driven_by :rack_test
  end
end
