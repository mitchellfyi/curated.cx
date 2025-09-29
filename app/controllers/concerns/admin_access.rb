# frozen_string_literal: true

module AdminAccess
  extend ActiveSupport::Concern

  included do
    before_action :ensure_admin_access
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped
  end

  private

  def ensure_admin_access
    unless current_user&.admin? || (Current.tenant && current_user&.has_role?(:owner, Current.tenant))
      flash[:alert] = "Access denied. Admin privileges required."
      redirect_to root_path
    end
  end
end
