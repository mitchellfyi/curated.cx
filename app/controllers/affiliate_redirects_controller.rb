# frozen_string_literal: true

# Controller for tracking affiliate link clicks and redirecting users
#
# Route: GET /go/:id
#
# This endpoint:
# 1. Finds the entry by ID
# 2. Tracks the click for analytics
# 3. Redirects to the affiliate URL (or canonical URL if no affiliate)
#
class AffiliateRedirectsController < ApplicationController
  skip_after_action :verify_authorized
  rate_limit to: 100, within: 1.minute, only: :show, with: -> { head :too_many_requests }

  def show
    @entry = find_entry

    unless @entry
      redirect_to root_path, alert: t("affiliate.entry_not_found")
      return
    end

    track_click
    redirect_to destination_url, allow_other_host: true
  end

  private

  def find_entry
    Entry.find_by(id: params[:id], site_id: Current.site&.id)
  end

  def track_click
    return unless @entry.has_affiliate?
    AffiliateUrlService.track_click_for(@entry, request)
  rescue StandardError => e
    Rails.logger.error("Affiliate click tracking failed: #{e.message}")
  end

  def destination_url
    @entry.display_url || @entry.url_canonical
  end
end
