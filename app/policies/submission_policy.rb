# frozen_string_literal: true

class SubmissionPolicy < ApplicationPolicy
  # Users can view their own submissions
  def show?
    user && record.user_id == user.id
  end

  # Any signed-in user can list their submissions
  def index?
    user.present?
  end

  # Any signed-in user can create submissions
  def new?
    user.present?
  end

  def create?
    user.present?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user
        scope.where(site: Current.site)
      else
        scope.none
      end
    end
  end
end
