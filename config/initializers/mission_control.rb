# frozen_string_literal: true

# Mission Control Jobs configuration
# https://github.com/basecamp/mission_control-jobs

Rails.application.config.after_initialize do
  if defined?(MissionControl::Jobs)
    # Set authentication - admins only (handled via routes.rb authenticate block)
    MissionControl::Jobs.http_basic_auth_enabled = false

    # Use ApplicationController as base - Pundit callbacks check for mission_control_controller?
    # and skip verification for MissionControl::Jobs engine controllers
    MissionControl::Jobs.base_controller_class = "ApplicationController"
  end
end
