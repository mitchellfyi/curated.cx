# frozen_string_literal: true

class ContentViewPolicy < ApplicationPolicy
  def create?
    user.present? && Current.site.present?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless Current.site.present?

      scope.where(site: Current.site)
    end
  end
end
