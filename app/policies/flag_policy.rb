# frozen_string_literal: true

class FlagPolicy < ApplicationPolicy
  def create?
    return false unless user.present?
    return false unless Current.site.present?
    return false if user.banned_from?(Current.site)
    return false if flagging_own_content?

    true
  end

  def index?
    admin_or_owner_only?
  end

  def show?
    admin_or_owner_only?
  end

  def resolve?
    admin_or_owner_only?
  end

  def dismiss?
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

  def flagging_own_content?
    return false unless record.respond_to?(:flaggable)
    return false unless record.flaggable.respond_to?(:user_id)

    record.flaggable.user_id == user.id
  end

  def admin_or_owner_only?
    return true if user&.admin?
    return false unless Current.tenant && user

    user.has_role?(:owner, Current.tenant) || user.has_role?(:admin, Current.tenant)
  end
end
