# frozen_string_literal: true

module TenantResourcePolicy
  extend ActiveSupport::Concern

  included do
    def index?
      # Allow public access unless tenant requires private access
      return true unless Current.tenant&.requires_login?
      user.present?
    end

    def show?
      # Allow public access unless tenant requires private access
      return true unless Current.tenant&.requires_login?
      user.present?
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

    class Scope < ApplicationPolicy::Scope
      def resolve
        # Only return records for current tenant
        scope.where(tenant: Current.tenant)
      end
    end
  end

  private

  def admin_or_tenant_owner?
    user&.admin? || (Current.tenant && user&.has_role?(:owner, Current.tenant))
  end
end
