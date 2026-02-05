# frozen_string_literal: true

# Mission Control Jobs configuration
# https://github.com/basecamp/mission_control-jobs

Rails.application.config.after_initialize do
  if defined?(MissionControl::Jobs)
    # Configure the queue adapter that mission_control-jobs will use
    MissionControl::Jobs.base_controller_class = "ApplicationController"

    # Set authentication - admins only (handled via routes.rb authenticate block)
    MissionControl::Jobs.http_basic_auth_enabled = false
  end
end
