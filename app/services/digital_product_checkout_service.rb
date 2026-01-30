# frozen_string_literal: true

# Service for creating Stripe Checkout sessions for digital products.
#
# Usage:
#   service = DigitalProductCheckoutService.new(product, email: "customer@example.com")
#   session = service.create_session(success_url:, cancel_url:)
#
# For free products:
#   purchase = service.purchase_free!
#
class DigitalProductCheckoutService
  class StripeNotConfiguredError < StandardError; end
  class ProductNotPublishedError < StandardError; end

  attr_reader :digital_product, :email

  # @param digital_product [DigitalProduct] The product to create checkout for
  # @param email [String] Customer email address
  def initialize(digital_product, email:)
    @digital_product = digital_product
    @email = email

    validate!
  end

  # Creates a Stripe Checkout session for paid products.
  # @param success_url [String] URL to redirect to on success
  # @param cancel_url [String] URL to redirect to on cancel
  # @return [Stripe::Checkout::Session] The created session
  def create_session(success_url:, cancel_url:)
    raise ProductNotPublishedError, "Product is not published" unless digital_product.published?

    Stripe::Checkout::Session.create(session_params(success_url, cancel_url))
  end

  # Handles free product purchases directly without Stripe.
  # @return [Purchase] The created purchase record
  def purchase_free!
    raise ProductNotPublishedError, "Product is not published" unless digital_product.published?
    raise ArgumentError, "Product is not free" unless digital_product.free?

    purchase = create_purchase(amount_cents: 0, source: :checkout)
    create_download_token(purchase)
    purchase
  end

  private

  def validate!
    raise StripeNotConfiguredError, "Stripe API key not configured" if Stripe.api_key.blank?
  end

  def session_params(success_url, cancel_url)
    {
      payment_method_types: [ "card" ],
      mode: "payment",
      line_items: [ line_item ],
      success_url: success_url,
      cancel_url: cancel_url,
      metadata: session_metadata,
      customer_email: email,
      expires_at: 30.minutes.from_now.to_i
    }
  end

  def line_item
    {
      price_data: {
        currency: "usd",
        product_data: {
          name: digital_product.title,
          description: product_description
        },
        unit_amount: digital_product.price_cents
      },
      quantity: 1
    }
  end

  def product_description
    digital_product.description.presence || "Digital download"
  end

  def session_metadata
    {
      checkout_type: "digital_product",
      digital_product_id: digital_product.id.to_s,
      site_id: digital_product.site_id.to_s,
      purchaser_email: email
    }
  end

  def create_purchase(amount_cents:, source:)
    Purchase.create!(
      site: digital_product.site,
      digital_product: digital_product,
      email: email,
      amount_cents: amount_cents,
      source: source,
      purchased_at: Time.current
    )
  end

  def create_download_token(purchase)
    DownloadToken.create!(purchase: purchase)
  end
end
