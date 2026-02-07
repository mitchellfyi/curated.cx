# frozen_string_literal: true

# Base controller for MissionControl::Jobs engine
# Inherits authentication from ApplicationController but skips Pundit verification
# since MissionControl's internal controllers don't use Pundit
class MissionControlBaseController < ApplicationController
  # Skip Pundit verification - MissionControl handles its own authorization
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  # Authentication is still required via the routes.rb authenticate block
end
