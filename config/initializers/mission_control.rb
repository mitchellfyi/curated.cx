# frozen_string_literal: true

# Mission Control Jobs configuration
# https://github.com/basecamp/mission_control-jobs

Rails.application.config.after_initialize do
  if defined?(MissionControl::Jobs)
    # Set authentication - admins only (handled via routes.rb authenticate block)
    MissionControl::Jobs.http_basic_auth_enabled = false

    # Use custom base controller that skips Pundit verification
    # MissionControl's controllers don't use Pundit, so we need to bypass the
    # after_action :verify_authorized and :verify_policy_scoped callbacks
    MissionControl::Jobs.base_controller_class = "MissionControlBaseController"
  end
end
