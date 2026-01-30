# frozen_string_literal: true

# Mux configuration for live video streaming.
# Set MUX_TOKEN_ID and MUX_TOKEN_SECRET in your environment.
# For webhooks, set MUX_WEBHOOK_SECRET.
#
# In development, use test keys from https://dashboard.mux.com/settings/access-tokens
# In production, use live keys.

Rails.application.config.mux = {
  token_id: ENV.fetch("MUX_TOKEN_ID", nil),
  token_secret: ENV.fetch("MUX_TOKEN_SECRET", nil),
  webhook_secret: ENV.fetch("MUX_WEBHOOK_SECRET", nil)
}

# Configure Mux Ruby gem
MuxRuby.configure do |config|
  config.username = Rails.application.config.mux[:token_id]
  config.password = Rails.application.config.mux[:token_secret]
end
