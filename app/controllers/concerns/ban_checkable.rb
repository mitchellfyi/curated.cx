# frozen_string_literal: true

# BanCheckable concern provides ban status checking for controllers.
# Include this module in controllers that need to prevent banned users from taking actions.
#
# Example usage:
#   class CommentsController < ApplicationController
#     include BanCheckable
#
#     before_action :check_ban_status, only: [:create, :update]
#   end
module BanCheckable
  extend ActiveSupport::Concern

  private

  # Check if the current user is banned from the current site.
  # If banned, responds with appropriate error format.
  def check_ban_status
    return unless current_user&.banned_from?(Current.site)

    message = I18n.t("errors.user_banned", default: "You are banned from this site.")

    respond_to do |format|
      format.html { redirect_back fallback_location: root_path, alert: message }
      format.json { render json: { error: message }, status: :forbidden }
      format.turbo_stream { head :forbidden }
    end
  end
end
