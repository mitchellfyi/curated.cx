# frozen_string_literal: true

class SearchPolicy < ApplicationPolicy
  def index?
    # Public access unless tenant requires login
    return true unless Current.tenant&.requires_login?
    user.present?
  end
end
