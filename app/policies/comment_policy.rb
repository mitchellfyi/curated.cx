# frozen_string_literal: true

class CommentPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    return false unless user.present?
    return false unless Current.site.present?
    return false if user.banned_from?(Current.site)
    return false if content_item_comments_locked?
    true
  end

  def update?
    return false unless user.present?
    return false unless Current.site.present?
    return false if user.banned_from?(Current.site)
    record.user_id == user.id
  end

  def destroy?
    return false unless user.present?
    admin_or_owner_only?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless Current.site.present?
      scope.where(site: Current.site)
    end
  end

  private

  def content_item_comments_locked?
    record.respond_to?(:content_item) && record.content_item&.comments_locked?
  end

  def admin_or_owner_only?
    return true if user&.admin?
    return false unless Current.tenant && user

    user.has_role?(:owner, Current.tenant) || user.has_role?(:admin, Current.tenant)
  end
end
