# frozen_string_literal: true

# Controller for handling boost click tracking.
# Records clicks and redirects to the target site.
class BoostsController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  # GET /boosts/:id/click
  # Records a click and redirects to the source site
  def click
    boost = NetworkBoost.find(params[:id])

    # Record the click (may return nil if deduplicated)
    BoostAttributionService.record_click(
      boost: boost,
      ip: request.remote_ip
    )

    # Redirect to the source site being promoted
    redirect_url = build_redirect_url(boost.source_site)
    redirect_to redirect_url, allow_other_host: true
  end

  private

  def build_redirect_url(site)
    hostname = site.primary_hostname
    return root_url if hostname.blank?

    "https://#{hostname}"
  end
end
