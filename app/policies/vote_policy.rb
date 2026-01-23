# frozen_string_literal: true

class VotePolicy < ApplicationPolicy
  def create?
    user_can_vote?
  end

  def destroy?
    user_can_vote? && record.user_id == user.id
  end

  def toggle?
    user_can_vote?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless Current.site.present?
      scope.where(site: Current.site)
    end
  end

  private

  def user_can_vote?
    return false unless user.present?
    return false unless Current.site.present?
    return false if user.banned_from?(Current.site)
    true
  end
end
