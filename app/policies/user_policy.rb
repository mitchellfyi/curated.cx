# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  def show_profile?
    # Public profiles
    true
  end

  def edit_profile?
    user.present? && user.id == record.id
  end

  def update_profile?
    edit_profile?
  end
end
