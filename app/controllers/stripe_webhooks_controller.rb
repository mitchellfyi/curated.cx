# frozen_string_literal: true

# Controller for handling Stripe webhooks.
# Verifies webhook signatures and delegates to StripeWebhookHandler.
#
# Route: POST /webhooks/stripe
#
class StripeWebhooksController < ApplicationController
  include WebhookController

  private

  def signature_header_value
    request.env["HTTP_STRIPE_SIGNATURE"]
  end

  def webhook_secret
    Rails.application.config.stripe[:webhook_secret]
  end

  def verify_and_construct_event(payload, sig_header, secret)
    build_stripe_event(payload, sig_header, secret)
  rescue Stripe::SignatureVerificationError => e
    Rails.logger.error("Invalid Stripe signature: #{e.message}")
    nil
  end

  def handler_class
    StripeWebhookHandler
  end

  def build_stripe_event(payload, sig_header, secret)
    if secret.present?
      Stripe::Webhook.construct_event(payload, sig_header, secret)
    else
      # In development without webhook secret, parse directly
      Rails.logger.warn("Stripe webhook secret not configured, skipping signature verification")
      data = JSON.parse(payload, symbolize_names: true)
      Stripe::Event.construct_from(data)
    end
  end
end
