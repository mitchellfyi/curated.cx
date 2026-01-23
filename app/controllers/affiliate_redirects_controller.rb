# frozen_string_literal: true

# Controller for tracking affiliate link clicks and redirecting users
#
# Route: GET /go/:id
#
# This endpoint:
# 1. Finds the listing by ID
# 2. Tracks the click for analytics
# 3. Redirects to the affiliate URL (or canonical URL if no affiliate)
#
class AffiliateRedirectsController < ApplicationController
  # Skip default Pundit authorization - this is a public redirect endpoint
  skip_after_action :verify_authorized

  # Rate limit to prevent abuse
  rate_limit to: 100, within: 1.minute, only: :show, with: -> { head :too_many_requests }

  def show
    @listing = find_listing

    unless @listing
      redirect_to root_path, alert: t("affiliate.listing_not_found")
      return
    end

    # Track the click
    track_click

    # Redirect to the appropriate URL
    redirect_to destination_url, allow_other_host: true
  end

  private

  def find_listing
    Listing.find_by(id: params[:id], site_id: Current.site&.id)
  end

  def track_click
    return unless @listing.has_affiliate?

    AffiliateUrlService.track_click_for(@listing, request)
  rescue StandardError => e
    # Log but don't fail the redirect
    Rails.logger.error("Affiliate click tracking failed: #{e.message}")
  end

  def destination_url
    @listing.display_url || @listing.url_canonical
  end
end
