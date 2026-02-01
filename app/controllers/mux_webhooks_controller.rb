# frozen_string_literal: true

# Controller for handling Mux webhooks.
# Verifies webhook signatures and delegates to MuxWebhookHandler.
#
# Route: POST /webhooks/mux
#
class MuxWebhooksController < ApplicationController
  include WebhookController

  private

  def signature_header_value
    request.env["HTTP_MUX_SIGNATURE"]
  end

  def webhook_secret
    Rails.application.config.mux[:webhook_secret]
  end

  def verify_and_construct_event(payload, sig_header, secret)
    return nil unless verify_signature(payload, sig_header, secret)

    JSON.parse(payload)
  end

  def handler_class
    MuxWebhookHandler
  end

  def verify_signature(payload, sig_header, secret)
    # In development without webhook secret, skip verification
    if secret.blank?
      Rails.logger.warn("Mux webhook secret not configured, skipping signature verification")
      return true
    end

    return false if sig_header.blank?

    # Mux uses HMAC-SHA256 for webhook signatures
    # Format: t=timestamp,v1=signature
    parts = sig_header.split(",").to_h { |part| part.split("=", 2) }
    timestamp = parts["t"]
    signature = parts["v1"]

    return false if timestamp.blank? || signature.blank?

    # Verify signature
    signed_payload = "#{timestamp}.#{payload}"
    expected_signature = OpenSSL::HMAC.hexdigest("SHA256", secret, signed_payload)

    ActiveSupport::SecurityUtils.secure_compare(expected_signature, signature)
  end
end
