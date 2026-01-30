# frozen_string_literal: true

# Policy for landing page authorization.
# Public users can view published landing pages.
# Admin users can manage all landing pages.
class LandingPagePolicy < ApplicationPolicy
  def show?
    # Public can view published pages
    record.published? || user_is_admin?
  end

  def index?
    user_is_admin?
  end

  def create?
    user_is_admin?
  end

  def update?
    user_is_admin?
  end

  def destroy?
    user_is_admin?
  end

  class Scope < Scope
    def resolve
      if user&.admin?
        scope.where(site: Current.site)
      else
        scope.where(site: Current.site).published
      end
    end
  end
end
