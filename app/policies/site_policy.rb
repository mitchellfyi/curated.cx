# frozen_string_literal: true

class SitePolicy < ApplicationPolicy
  def index?
    user.present? && Current.tenant.present?
  end

  def show?
    index?
  end

  def create?
    user.present? && Current.tenant.present?
  end

  def new?
    create?
  end

  def update?
    user.present? && (user.admin? || record.tenant == Current.tenant)
  end

  def edit?
    update?
  end

  def destroy?
    user.present? && (user.admin? || (record.tenant == Current.tenant && user.has_role?(:owner, Current.tenant)))
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user&.admin?
        scope.all
      elsif Current.tenant.present?
        scope.where(tenant: Current.tenant)
      else
        scope.none
      end
    end
  end
end
