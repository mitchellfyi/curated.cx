# frozen_string_literal: true

class SiteBanPolicy < ApplicationPolicy
  def index?
    admin_or_owner_only?
  end

  def show?
    admin_or_owner_only?
  end

  def create?
    admin_or_owner_only?
  end

  def update?
    admin_or_owner_only?
  end

  def destroy?
    admin_or_owner_only?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless Current.site.present?
      return scope.none unless admin_or_owner_only?
      scope.where(site: Current.site)
    end

    private

    def admin_or_owner_only?
      return true if user&.admin?
      return false unless Current.tenant && user

      user.has_role?(:owner, Current.tenant) || user.has_role?(:admin, Current.tenant)
    end
  end

  private

  def admin_or_owner_only?
    return true if user&.admin?
    return false unless Current.tenant && user

    user.has_role?(:owner, Current.tenant) || user.has_role?(:admin, Current.tenant)
  end
end
