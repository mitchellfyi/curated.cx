# frozen_string_literal: true

class TenantPolicy < ApplicationPolicy
  def show?
    # Anyone can view tenant information if the tenant is publicly accessible
    # For private access tenants, users with appropriate roles can access them
    return true if record.publicly_accessible?
    return false unless record.private_access?

    user_has_tenant_role?([ :viewer, :editor, :admin, :owner ])
  end

  def about?
    # Anyone can view tenant about page if the tenant is publicly accessible
    # For private access tenants, users with appropriate roles can access them
    return true if record.publicly_accessible?
    return false unless record.private_access?

    user_has_tenant_role?([ :viewer, :editor, :admin, :owner ])
  end

  def index?
    # Only admins can list all tenants
    user&.admin?
  end

  def create?
    # Only admins can create tenants
    user&.admin?
  end

  def update?
    # Only admins can update tenants
    user&.admin?
  end

  def destroy?
    # Only admins can destroy tenants
    user&.admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user&.admin?
        scope.all
      else
        # Non-admins can only see publicly accessible tenants
        scope.where(status: [ :enabled, :private_access ])
      end
    end
  end
end
