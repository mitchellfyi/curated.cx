# frozen_string_literal: true

class CategoryPolicy < ApplicationPolicy
  def index?
    true # Public access to categories
  end

  def show?
    true # Public access to category
  end

  def create?
    admin_or_tenant_owner?
  end

  def update?
    admin_or_tenant_owner?
  end

  def destroy?
    admin_or_tenant_owner?
  end

  class Scope < Scope
    def resolve
      # Only return categories for current tenant
      scope.where(tenant: Current.tenant)
    end
  end

  private

  def admin_or_tenant_owner?
    user&.admin? || (Current.tenant && user&.has_role?(:owner, Current.tenant))
  end
end