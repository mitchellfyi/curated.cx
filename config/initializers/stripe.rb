# frozen_string_literal: true

# Stripe configuration for payment processing.
# Set STRIPE_SECRET_KEY and STRIPE_PUBLISHABLE_KEY in your environment.
# For webhooks, set STRIPE_WEBHOOK_SECRET.
#
# In development, use test keys from https://dashboard.stripe.com/test/apikeys
# In production, use live keys.

Rails.application.config.stripe = {
  secret_key: ENV.fetch("STRIPE_SECRET_KEY", nil),
  publishable_key: ENV.fetch("STRIPE_PUBLISHABLE_KEY", nil),
  webhook_secret: ENV.fetch("STRIPE_WEBHOOK_SECRET", nil)
}

# Configure Stripe gem
Stripe.api_key = Rails.application.config.stripe[:secret_key]

# Set API version for consistent behavior
Stripe.api_version = "2024-12-18.acacia"

# Configure logging in development
if Rails.env.development?
  Stripe.log_level = Stripe::LEVEL_INFO
end
