# frozen_string_literal: true

# RateLimitable concern provides rate limiting functionality using Rails.cache.
# Include this module in controllers to add rate limiting capabilities.
#
# Example usage:
#   class VotesController < ApplicationController
#     include RateLimitable
#
#     def create
#       return render_rate_limited if rate_limited?(current_user, :vote, limit: 100, period: 1.hour)
#       track_action(current_user, :vote)
#       # ... create vote
#     end
#   end
module RateLimitable
  extend ActiveSupport::Concern

  # Track an action for rate limiting purposes
  # @param user [User] the user performing the action
  # @param action [Symbol] the action being performed
  # @param site [Site] optional site scope (defaults to Current.site)
  def track_action(user, action, site: nil)
    return unless user.present?

    site ||= Current.site
    key = rate_limit_key(user, action, site)
    count = Rails.cache.read(key).to_i
    # Use 1 hour expiry as base, tracking will be per-hour windows
    Rails.cache.write(key, count + 1, expires_in: 1.hour)
  end

  # Check if a user is rate limited for an action
  # @param user [User] the user to check
  # @param action [Symbol] the action being performed
  # @param limit [Integer] maximum actions allowed
  # @param period [ActiveSupport::Duration] time period for the limit
  # @param site [Site] optional site scope (defaults to Current.site)
  # @return [Boolean] true if rate limited
  def rate_limited?(user, action, limit:, period:, site: nil)
    return false unless user.present?

    site ||= Current.site
    key = rate_limit_key(user, action, site)
    count = Rails.cache.read(key).to_i
    count >= limit
  end

  # Get remaining actions for a user
  # @param user [User] the user to check
  # @param action [Symbol] the action being performed
  # @param limit [Integer] maximum actions allowed
  # @param site [Site] optional site scope (defaults to Current.site)
  # @return [Integer] remaining actions
  def remaining_actions(user, action, limit:, site: nil)
    return limit unless user.present?

    site ||= Current.site
    key = rate_limit_key(user, action, site)
    count = Rails.cache.read(key).to_i
    [ limit - count, 0 ].max
  end

  # Render a rate limited response
  # @param message [String] optional custom message
  def render_rate_limited(message: nil)
    message ||= I18n.t("errors.rate_limited", default: "You have exceeded the rate limit. Please try again later.")
    respond_to do |format|
      format.html { redirect_back fallback_location: root_path, alert: message }
      format.json { render json: { error: message }, status: :too_many_requests }
      format.turbo_stream { render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash", locals: { flash: { alert: message } }), status: :too_many_requests }
    end
  end

  private

  def rate_limit_key(user, action, site)
    site_id = site&.id || "global"
    "rate_limit:#{site_id}:#{user.id}:#{action}:#{Time.current.beginning_of_hour.to_i}"
  end
end
