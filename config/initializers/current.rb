# frozen_string_literal: true

# Current context for storing request-scoped data
class Current < ActiveSupport::CurrentAttributes
  attribute :tenant

  # Reset the current tenant (useful for testing)
  def self.reset_tenant!
    reset
  end

  # Ensure we always have a tenant set
  def self.ensure_tenant!
    raise "No tenant set in Current context" if tenant.nil?
  end
end
