# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: -> { Rails.application.config.action_mailer.default_options&.dig(:from) || "noreply@curated.cx" }
  layout "mailer"

  private

  # Helper to get site-specific from address
  def site_from_address
    if Current.site&.setting("email.from_address").present?
      Current.site.setting("email.from_address")
    else
      self.class.default[:from]
    end
  end
end
