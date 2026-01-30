# frozen_string_literal: true

class ListingPolicy < ApplicationPolicy
  include TenantResourcePolicy

  # Allow checkout for authenticated users who submitted the listing
  # or for admins/editors
  def checkout?
    return false unless user.present?
    return true if user_is_admin?
    return true if user_has_tenant_role?(%i[admin editor])

    # Allow the listing submitter to checkout
    record.respond_to?(:submitted_by_id) && record.submitted_by_id == user.id
  end
end
