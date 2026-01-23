# frozen_string_literal: true

class ContentItemPolicy < ApplicationPolicy
  def index?
    # Public access unless tenant requires login
    return true unless Current.tenant&.requires_login?
    user.present?
  end

  def show?
    return false unless record&.published?
    return true unless Current.tenant&.requires_login?
    user.present?
  end

  def create?
    admin_or_editor?
  end

  def update?
    admin_or_editor?
  end

  def destroy?
    admin_or_owner_only?
  end

  # Moderation actions
  def hide?
    admin_or_owner_only?
  end

  def unhide?
    admin_or_owner_only?
  end

  def lock_comments?
    admin_or_owner_only?
  end

  def unlock_comments?
    admin_or_owner_only?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless Current.site.present?
      scope.where(site: Current.site)
    end
  end

  private

  def admin_or_editor?
    return true if user&.admin?
    return false unless Current.tenant && user

    user.has_role?(:owner, Current.tenant) ||
      user.has_role?(:admin, Current.tenant) ||
      user.has_role?(:editor, Current.tenant)
  end

  def admin_or_owner_only?
    return true if user&.admin?
    return false unless Current.tenant && user

    user.has_role?(:owner, Current.tenant) ||
      user.has_role?(:admin, Current.tenant)
  end
end
