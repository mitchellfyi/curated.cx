# frozen_string_literal: true

# Controller for handling Mux webhooks.
# Verifies webhook signatures and delegates to MuxWebhookHandler.
#
# Route: POST /webhooks/mux
#
class MuxWebhooksController < ApplicationController
  # Skip CSRF and authentication for webhooks
  skip_before_action :verify_authenticity_token
  skip_after_action :verify_authorized

  # POST /webhooks/mux
  def create
    payload = request.body.read
    sig_header = request.env["HTTP_MUX_SIGNATURE"]
    webhook_secret = Rails.application.config.mux[:webhook_secret]

    unless verify_signature(payload, sig_header, webhook_secret)
      Rails.logger.error("Invalid Mux webhook signature")
      render json: { error: "Invalid signature" }, status: :bad_request
      return
    end

    begin
      event = JSON.parse(payload)
    rescue JSON::ParserError => e
      Rails.logger.error("Invalid JSON payload: #{e.message}")
      render json: { error: "Invalid payload" }, status: :bad_request
      return
    end

    # Process the event
    handler = MuxWebhookHandler.new(event)

    if handler.process
      render json: { received: true }, status: :ok
    else
      render json: { error: "Processing failed" }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error("Mux webhook error: #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n"))
    render json: { error: "Internal error" }, status: :internal_server_error
  end

  private

  def verify_signature(payload, sig_header, webhook_secret)
    # In development without webhook secret, skip verification
    if webhook_secret.blank?
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
    expected_signature = OpenSSL::HMAC.hexdigest("SHA256", webhook_secret, signed_payload)

    ActiveSupport::SecurityUtils.secure_compare(expected_signature, signature)
  end
end
