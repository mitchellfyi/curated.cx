# frozen_string_literal: true

# Mailer for sending payment receipt emails.
class PaymentReceiptMailer < ApplicationMailer
  # Send a payment receipt to the customer.
  # @param entry [Entry] The entry (directory) that was paid for
  # @param session [Stripe::Checkout::Session] The completed checkout session
  def receipt(entry, session)
    @entry = entry
    @session = session
    @checkout_type = session.metadata["checkout_type"]
    @duration_days = session.metadata["duration_days"]
    @amount = session.amount_total / 100.0
    @currency = session.currency.upcase

    customer_email = session.customer_email || session.customer_details&.email
    return unless customer_email.present?

    mail(
      to: customer_email,
      subject: t("payment_receipt.subject", listing_title: @entry.title)
    )
  end
end
