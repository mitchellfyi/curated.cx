# frozen_string_literal: true

class TenantPolicy < ApplicationPolicy
  def show?
    # Anyone can view tenant information if the tenant is publicly accessible
    record.publicly_accessible?
  end

  def about?
    # Anyone can view tenant about page if the tenant is publicly accessible
    record.publicly_accessible?
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
        scope.active
      end
    end
  end
end
