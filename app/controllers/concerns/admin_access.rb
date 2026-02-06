# frozen_string_literal: true

module AdminAccess
  extend ActiveSupport::Concern

  included do
    layout "admin"
    before_action :require_admin_access
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped
  end

  private

  def require_admin_access
    return if current_user&.admin?
    return if Current.tenant && %i[owner admin editor].any? { |role| current_user&.has_role?(role, Current.tenant) }

    if current_user.nil?
      redirect_to new_user_session_path
    else
      raise Pundit::NotAuthorizedError, "Admin access required"
    end
  end

  alias_method :ensure_admin_access, :require_admin_access
end
