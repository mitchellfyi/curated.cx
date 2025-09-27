ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # Ensure tenants are seeded for tests
    setup do
      # Seed tenants if they don't exist
      unless Tenant.exists?(slug: "root")
        Rails.application.load_seed
      end
    end
  end
end
