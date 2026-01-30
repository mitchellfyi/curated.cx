# frozen_string_literal: true

# Handles Stripe webhook events for payment processing.
#
# Supported events:
# - checkout.session.completed: Payment successful
# - checkout.session.expired: Session expired without payment
# - payment_intent.payment_failed: Payment failed
# - charge.refunded: Payment refunded
#
class StripeWebhookHandler
  class UnhandledEventError < StandardError; end

  attr_reader :event

  def initialize(event)
    @event = event
  end

  # Process the webhook event
  # @return [Boolean] true if handled successfully
  def process
    case event.type
    when "checkout.session.completed"
      handle_checkout_completed(event.data.object)
    when "checkout.session.expired"
      handle_checkout_expired(event.data.object)
    when "payment_intent.payment_failed"
      handle_payment_failed(event.data.object)
    when "charge.refunded"
      handle_charge_refunded(event.data.object)
    else
      Rails.logger.info("Unhandled Stripe event type: #{event.type}")
      true
    end
  end

  private

  # Handle successful checkout completion
  def handle_checkout_completed(session)
    checkout_type = session.metadata["checkout_type"]

    # Route to appropriate handler based on checkout type
    if checkout_type == "digital_product"
      handle_digital_product_purchase(session)
    else
      handle_listing_checkout(session)
    end
  end

  # Handle listing-based checkout (jobs, featured placements)
  def handle_listing_checkout(session)
    listing = find_listing_by_session(session.id)
    return true unless listing

    checkout_type = session.metadata["checkout_type"]&.to_sym
    duration_days = session.metadata["duration_days"]&.to_i

    ActiveRecord::Base.transaction do
      # Mark as paid
      listing.update!(
        payment_status: :paid,
        stripe_payment_intent_id: session.payment_intent,
        paid: true,
        payment_reference: session.payment_intent
      )

      # Apply the appropriate benefit based on checkout type
      apply_listing_benefit(listing, checkout_type, duration_days)
    end

    # Send receipt email
    send_payment_receipt(listing, session)

    Rails.logger.info("Payment completed for listing #{listing.id}")
    true
  rescue StandardError => e
    Rails.logger.error("Error handling checkout.session.completed: #{e.message}")
    raise
  end

  # Handle digital product purchase
  def handle_digital_product_purchase(session)
    digital_product_id = session.metadata["digital_product_id"]
    purchaser_email = session.metadata["purchaser_email"]
    site_id = session.metadata["site_id"]

    # Check if purchase already exists (idempotency)
    existing_purchase = Purchase.find_by(stripe_checkout_session_id: session.id)
    return true if existing_purchase

    digital_product = DigitalProduct.unscoped.find(digital_product_id)

    purchase = nil
    ActiveRecord::Base.transaction do
      purchase = Purchase.create!(
        site_id: site_id,
        digital_product: digital_product,
        email: purchaser_email,
        amount_cents: session.amount_total,
        stripe_payment_intent_id: session.payment_intent,
        stripe_checkout_session_id: session.id,
        source: :checkout,
        purchased_at: Time.current
      )

      DownloadToken.create!(purchase: purchase)
    end

    # Send delivery email with download link
    DigitalProductMailer.purchase_receipt(purchase).deliver_later

    Rails.logger.info("Digital product purchase completed: #{purchase.id}")
    true
  rescue StandardError => e
    Rails.logger.error("Error handling digital product purchase: #{e.message}")
    raise
  end

  # Handle expired checkout session
  def handle_checkout_expired(session)
    listing = find_listing_by_session(session.id)
    return true unless listing

    listing.update!(payment_status: :unpaid)

    Rails.logger.info("Checkout expired for listing #{listing.id}")
    true
  end

  # Handle failed payment
  def handle_payment_failed(payment_intent)
    listing = Listing.find_by(stripe_payment_intent_id: payment_intent.id)
    return true unless listing

    listing.update!(payment_status: :payment_failed)

    Rails.logger.info("Payment failed for listing #{listing.id}")
    true
  end

  # Handle refund
  def handle_charge_refunded(charge)
    payment_intent_id = charge.payment_intent
    listing = Listing.find_by(stripe_payment_intent_id: payment_intent_id)
    return true unless listing

    listing.update!(
      payment_status: :refunded,
      paid: false
    )

    # Remove benefits
    remove_listing_benefits(listing)

    Rails.logger.info("Payment refunded for listing #{listing.id}")
    true
  end

  def find_listing_by_session(session_id)
    Listing.find_by(stripe_checkout_session_id: session_id)
  end

  def apply_listing_benefit(listing, checkout_type, duration_days)
    return unless checkout_type && duration_days&.positive?

    case checkout_type.to_s
    when /^job_post/
      # Job post: set expiry date
      listing.update!(
        expires_at: duration_days.days.from_now,
        published_at: Time.current
      )
    when /^featured/
      # Featured placement: set featured dates
      listing.update!(
        featured_from: Time.current,
        featured_until: duration_days.days.from_now
      )
    end
  end

  def remove_listing_benefits(listing)
    listing.update!(
      featured_from: nil,
      featured_until: nil
    )
  end

  def send_payment_receipt(listing, session)
    # Queue receipt email
    PaymentReceiptMailer.receipt(listing, session).deliver_later
  rescue StandardError => e
    # Don't fail the webhook if email fails
    Rails.logger.error("Failed to send payment receipt email: #{e.message}")
  end
end
