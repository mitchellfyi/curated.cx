# frozen_string_literal: true

class LiveStreamPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    return true if record.visibility_public_access?
    return false unless user.present?

    user_is_subscriber?
  end

  def new?
    create?
  end

  def create?
    return false unless user.present?
    return false unless Current.site&.streaming_enabled?

    admin_or_owner_only?
  end

  def update?
    return false unless user.present?

    admin_or_owner_only?
  end

  def destroy?
    return false unless user.present?

    admin_or_owner_only?
  end

  def start?
    return false unless user.present?
    return false unless record.can_start?

    admin_or_owner_only?
  end

  def end_stream?
    return false unless user.present?
    return false unless record.can_end?

    admin_or_owner_only?
  end

  def join?
    show?
  end

  def leave?
    true
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless Current.site.present?

      base = scope.where(site: Current.site)

      if user.present? && user_is_subscriber?
        base
      else
        base.publicly_visible
      end
    end

    private

    def user_is_subscriber?
      return false unless user.present?
      return true if user.admin?

      DigestSubscription.where(user: user, site: Current.site).active.exists?
    end
  end

  private

  def user_is_subscriber?
    return false unless user.present?
    return true if user.admin?

    DigestSubscription.where(user: user, site: Current.site).active.exists?
  end

  def admin_or_owner_only?
    return true if user&.admin?
    return false unless Current.tenant && user

    user.has_role?(:owner, Current.tenant) || user.has_role?(:admin, Current.tenant)
  end
end
