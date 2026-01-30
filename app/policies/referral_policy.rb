# frozen_string_literal: true

class ReferralPolicy < ApplicationPolicy
  def show?
    user.present?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      # Users can only see their own referrals through their subscriptions
      scope.none
    end
  end
end
