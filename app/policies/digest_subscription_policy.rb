# frozen_string_literal: true

class DigestSubscriptionPolicy < ApplicationPolicy
  def show?
    user.present?
  end

  def create?
    user.present?
  end

  def update?
    user.present? && record.user_id == user.id
  end

  def destroy?
    user.present? && record.user_id == user.id
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user: user)
    end
  end
end
