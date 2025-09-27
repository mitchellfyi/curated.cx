# frozen_string_literal: true

# Configure tenant resolver middleware
require_relative "../../app/middleware/tenant_resolver"

Rails.application.configure do
  config.middleware.use TenantResolver
end
