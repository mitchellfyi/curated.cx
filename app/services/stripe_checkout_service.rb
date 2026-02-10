# frozen_string_literal: true

# Service for creating Stripe Checkout sessions for entries.
#
# Usage:
#   service = StripeCheckoutService.new(entry, checkout_type: :job_post)
#   session = service.create_session(success_url:, cancel_url:)
#
class StripeCheckoutService
  class StripeNotConfiguredError < StandardError; end
  class InvalidCheckoutTypeError < StandardError; end

  # Price configurations for different entry types and durations
  PRICE_CONFIGS = {
    job_post_30: {
      name: "Job Posting - 30 Days",
      description: "List your job for 30 days",
      amount: 99_00, # $99.00
      currency: "usd",
      duration_days: 30
    },
    job_post_60: {
      name: "Job Posting - 60 Days",
      description: "List your job for 60 days",
      amount: 179_00, # $179.00
      currency: "usd",
      duration_days: 60
    },
    job_post_90: {
      name: "Job Posting - 90 Days",
      description: "List your job for 90 days",
      amount: 249_00, # $249.00
      currency: "usd",
      duration_days: 90
    },
    featured_7: {
      name: "Featured Placement - 7 Days",
      description: "Feature your entry for 7 days",
      amount: 49_00, # $49.00
      currency: "usd",
      duration_days: 7
    },
    featured_14: {
      name: "Featured Placement - 14 Days",
      description: "Feature your entry for 14 days",
      amount: 89_00, # $89.00
      currency: "usd",
      duration_days: 14
    },
    featured_30: {
      name: "Featured Placement - 30 Days",
      description: "Feature your entry for 30 days",
      amount: 149_00, # $149.00
      currency: "usd",
      duration_days: 30
    }
  }.freeze

  attr_reader :entry, :checkout_type, :price_config

  # @param entry [Entry] The entry to create checkout for
  # @param checkout_type [Symbol] One of the PRICE_CONFIGS keys
  def initialize(entry, checkout_type:)
    @entry = entry
    @checkout_type = checkout_type.to_sym
    @price_config = PRICE_CONFIGS[@checkout_type]

    validate!
  end

  # Creates a Stripe Checkout session.
  # @param success_url [String] URL to redirect to on success
  # @param cancel_url [String] URL to redirect to on cancel
  # @return [Stripe::Checkout::Session] The created session
  def create_session(success_url:, cancel_url:)
    session = Stripe::Checkout::Session.create(session_params(success_url, cancel_url))

    # Update entry with session ID and pending status
    entry.update!(
      stripe_checkout_session_id: session.id,
      payment_status: :pending_payment
    )

    session
  end

  # Returns the price in cents
  def price_amount
    price_config[:amount]
  end

  # Returns the duration in days
  def duration_days
    price_config[:duration_days]
  end

  private

  def validate!
    raise StripeNotConfiguredError, "Stripe API key not configured" if Stripe.api_key.blank?
    raise InvalidCheckoutTypeError, "Unknown checkout type: #{checkout_type}" if price_config.nil?
  end

  def session_params(success_url, cancel_url)
    {
      payment_method_types: [ "card" ],
      mode: "payment",
      line_items: [ line_item ],
      success_url: success_url,
      cancel_url: cancel_url,
      metadata: session_metadata,
      client_reference_id: entry.id.to_s,
      customer_email: customer_email,
      expires_at: 30.minutes.from_now.to_i
    }
  end

  def line_item
    {
      price_data: {
        currency: price_config[:currency],
        product_data: {
          name: price_config[:name],
          description: product_description
        },
        unit_amount: price_config[:amount]
      },
      quantity: 1
    }
  end

  def product_description
    "#{price_config[:description]} - #{entry.title}"
  end

  def session_metadata
    {
      entry_id: entry.id.to_s,
      checkout_type: checkout_type.to_s,
      duration_days: price_config[:duration_days].to_s,
      site_id: entry.site_id.to_s,
      tenant_id: entry.tenant_id.to_s
    }
  end

  def customer_email
    # If entry was submitted by a user, use their email
    return nil unless entry.respond_to?(:submitted_by) && entry.submitted_by.present?

    entry.submitted_by.email
  end
end
