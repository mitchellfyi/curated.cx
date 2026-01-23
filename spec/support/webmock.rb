# frozen_string_literal: true

require "webmock/rspec"

# Disable all external HTTP requests by default
# Allow localhost for system tests and Selenium
WebMock.disable_net_connect!(allow_localhost: true)
