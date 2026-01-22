# frozen_string_literal: true

# Controller for displaying "domain not connected" error page
class DomainNotConnectedController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  def show
    # Get hostname from middleware or request
    @hostname = request.env["X_DOMAIN_NOT_CONNECTED"] || request.host
    render status: :not_found, layout: "application"
  end
end
