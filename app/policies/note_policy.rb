# frozen_string_literal: true

class NotePolicy < ApplicationPolicy
  def index?
    # Public access unless tenant requires login
    return true unless Current.tenant&.requires_login?
    user.present?
  end

  def show?
    # Only show published, non-hidden notes
    return false unless record&.published?
    return false if record&.hidden?
    return true unless Current.tenant&.requires_login?
    user.present?
  end

  def create?
    # Editors and above can create notes
    admin_or_editor?
  end

  def new?
    create?
  end

  def update?
    # Own note or admin
    return true if user&.admin?
    return true if admin_or_owner_only?
    record.user_id == user&.id
  end

  def edit?
    update?
  end

  def destroy?
    # Own note or admin
    return true if user&.admin?
    return true if admin_or_owner_only?
    record.user_id == user&.id
  end

  def repost?
    # Editors and above can repost notes
    admin_or_editor?
  end

  # Moderation actions
  def hide?
    admin_or_owner_only?
  end

  def unhide?
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
