# frozen_string_literal: true

# Mission Control Jobs configuration
# https://github.com/basecamp/mission_control-jobs

Rails.application.config.after_initialize do
  if defined?(MissionControl::Jobs)
    # Set authentication - admins only (handled via routes.rb authenticate block)
    MissionControl::Jobs.http_basic_auth_enabled = false

    # Configure the base controller class for styling and authentication inheritance
    # Note: Authentication is handled by the `authenticate :user` block in routes.rb
    MissionControl::Jobs.base_controller_class = "ApplicationController"
  end
end
