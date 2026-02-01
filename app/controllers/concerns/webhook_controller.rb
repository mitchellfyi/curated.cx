# frozen_string_literal: true

# WebhookController concern provides shared webhook handling logic for controllers.
# Include this module in controllers that handle incoming webhooks from external services.
#
# Example usage:
#   class MuxWebhooksController < ApplicationController
#     include WebhookController
#
#     private
#
#     def signature_header_value
#       request.env["HTTP_MUX_SIGNATURE"]
#     end
#
#     def webhook_secret
#       Rails.application.config.mux[:webhook_secret]
#     end
#
#     def verify_and_construct_event(payload, sig_header, secret)
#       return nil unless verify_signature(payload, sig_header, secret)
#       JSON.parse(payload)
#     end
#
#     def handler_class
#       MuxWebhookHandler
#     end
#   end
module WebhookController
  extend ActiveSupport::Concern

  included do
    skip_before_action :verify_authenticity_token
    skip_after_action :verify_authorized
  end

  # POST /webhooks/:provider
  def create
    payload = request.body.read
    sig_header = signature_header_value
    secret = webhook_secret

    event = verify_and_construct_event(payload, sig_header, secret)

    unless event
      Rails.logger.error("Invalid #{provider_name} webhook signature")
      return render_invalid_signature
    end

    process_event(event)
  rescue JSON::ParserError => e
    log_error("Invalid JSON payload", e)
    render_invalid_payload
  rescue StandardError => e
    log_error("#{provider_name} webhook error", e)
    render_internal_error
  end

  private

  def process_event(event)
    handler = handler_class.new(event)

    if handler.process
      render_success
    else
      render_processing_failed
    end
  end

  def provider_name
    self.class.name.delete_suffix("WebhooksController")
  end

  def log_error(message, exception)
    Rails.logger.error("#{message}: #{exception.message}")
    Rails.logger.error(exception.backtrace.first(10).join("\n"))
  end

  # Response helpers

  def render_success
    render json: { received: true }, status: :ok
  end

  def render_invalid_signature
    render json: { error: "Invalid signature" }, status: :bad_request
  end

  def render_invalid_payload
    render json: { error: "Invalid payload" }, status: :bad_request
  end

  def render_processing_failed
    render json: { error: "Processing failed" }, status: :unprocessable_entity
  end

  def render_internal_error
    render json: { error: "Internal error" }, status: :internal_server_error
  end

  # Template methods - must be overridden by including controllers

  # Override in controller: returns the signature header value from the request
  def signature_header_value
    raise NotImplementedError, "#{self.class}#signature_header_value must be implemented"
  end

  # Override in controller: returns the webhook secret from config
  def webhook_secret
    raise NotImplementedError, "#{self.class}#webhook_secret must be implemented"
  end

  # Override in controller: verifies signature and constructs event object
  # Returns event object on success, nil on signature verification failure
  def verify_and_construct_event(_payload, _sig_header, _secret)
    raise NotImplementedError, "#{self.class}#verify_and_construct_event must be implemented"
  end

  # Override in controller: returns the handler class for processing events
  def handler_class
    raise NotImplementedError, "#{self.class}#handler_class must be implemented"
  end
end
