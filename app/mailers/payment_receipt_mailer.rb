# frozen_string_literal: true

# Mailer for sending payment receipt emails.
class PaymentReceiptMailer < ApplicationMailer
  # Send a payment receipt to the customer.
  # @param listing [Listing] The listing that was paid for
  # @param session [Stripe::Checkout::Session] The completed checkout session
  def receipt(listing, session)
    @listing = listing
    @session = session
    @checkout_type = session.metadata["checkout_type"]
    @duration_days = session.metadata["duration_days"]
    @amount = session.amount_total / 100.0
    @currency = session.currency.upcase

    # Get customer email from session
    customer_email = session.customer_email || session.customer_details&.email
    return unless customer_email.present?

    mail(
      to: customer_email,
      subject: t("payment_receipt.subject", listing_title: @listing.title)
    )
  end
end
