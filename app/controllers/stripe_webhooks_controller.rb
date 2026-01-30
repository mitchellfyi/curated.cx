# frozen_string_literal: true

# Controller for handling Stripe webhooks.
# Verifies webhook signatures and delegates to StripeWebhookHandler.
#
# Route: POST /webhooks/stripe
#
class StripeWebhooksController < ApplicationController
  # Skip CSRF and authentication for webhooks
  skip_before_action :verify_authenticity_token
  skip_after_action :verify_authorized

  # POST /webhooks/stripe
  def create
    payload = request.body.read
    sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
    webhook_secret = Rails.application.config.stripe[:webhook_secret]

    begin
      event = construct_event(payload, sig_header, webhook_secret)
    rescue JSON::ParserError => e
      Rails.logger.error("Invalid JSON payload: #{e.message}")
      render json: { error: "Invalid payload" }, status: :bad_request
      return
    rescue Stripe::SignatureVerificationError => e
      Rails.logger.error("Invalid Stripe signature: #{e.message}")
      render json: { error: "Invalid signature" }, status: :bad_request
      return
    end

    # Process the event
    handler = StripeWebhookHandler.new(event)

    if handler.process
      render json: { received: true }, status: :ok
    else
      render json: { error: "Processing failed" }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error("Stripe webhook error: #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n"))
    render json: { error: "Internal error" }, status: :internal_server_error
  end

  private

  def construct_event(payload, sig_header, webhook_secret)
    if webhook_secret.present?
      Stripe::Webhook.construct_event(payload, sig_header, webhook_secret)
    else
      # In development without webhook secret, parse directly
      Rails.logger.warn("Stripe webhook secret not configured, skipping signature verification")
      data = JSON.parse(payload, symbolize_names: true)
      Stripe::Event.construct_from(data)
    end
  end
end
