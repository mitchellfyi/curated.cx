# frozen_string_literal: true

class DiscussionPostPolicy < ApplicationPolicy
  def create?
    return false unless user.present?
    return false if user.banned_from?(Current.site)
    return false if discussion_locked?

    true
  end

  def update?
    return false unless user.present?
    return false if user.banned_from?(Current.site)

    record.user_id == user.id
  end

  def destroy?
    return false unless user.present?

    record.user_id == user.id || admin_or_owner_only?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless Current.site.present?

      scope.where(site: Current.site)
    end
  end

  private

  def discussion_locked?
    record.respond_to?(:discussion) && record.discussion&.locked?
  end

  def admin_or_owner_only?
    return true if user&.admin?
    return false unless Current.tenant && user

    user.has_role?(:owner, Current.tenant) || user.has_role?(:admin, Current.tenant)
  end
end
