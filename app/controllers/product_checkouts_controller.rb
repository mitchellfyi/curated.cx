# frozen_string_literal: true

# Controller for digital product checkout flow.
#
# Routes:
#   POST /products/:product_id/checkout       - Create checkout session
#   GET  /products/:product_id/checkout/success - Payment success page
#   GET  /products/:product_id/checkout/cancel  - Payment cancelled page
#
class ProductCheckoutsController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped
  before_action :check_digital_products_enabled
  before_action :set_digital_product

  # POST /products/:product_id/checkout
  def create
    email = checkout_params[:email]

    if email.blank?
      redirect_to product_path(@digital_product.slug), alert: t("digital_products.checkout.error")
      return
    end

    service = DigitalProductCheckoutService.new(@digital_product, email: email)

    if @digital_product.free?
      handle_free_purchase(service)
    else
      handle_paid_checkout(service)
    end
  rescue DigitalProductCheckoutService::StripeNotConfiguredError
    redirect_to product_path(@digital_product.slug), alert: t("checkouts.stripe_not_configured")
  rescue DigitalProductCheckoutService::ProductNotPublishedError
    redirect_to products_path, alert: t("digital_products.checkout.error")
  rescue Stripe::StripeError => e
    Rails.logger.error("Stripe error during product checkout: #{e.message}")
    redirect_to product_path(@digital_product.slug), alert: t("digital_products.checkout.error")
  end

  # GET /products/:product_id/checkout/success
  def success
    flash.now[:notice] = t("digital_products.checkout.success_message")
  end

  # GET /products/:product_id/checkout/cancel
  def cancel
    flash.now[:alert] = t("digital_products.checkout.cancel_message")
  end

  private

  def set_digital_product
    @digital_product = DigitalProduct.visible.find_by!(slug: params[:product_id])
  end

  def checkout_params
    params.permit(:email)
  end

  def handle_free_purchase(service)
    purchase = service.purchase_free!
    DigitalProductMailer.purchase_receipt(purchase).deliver_later

    redirect_to success_product_checkout_path(@digital_product.slug)
  end

  def handle_paid_checkout(service)
    session = service.create_session(
      success_url: success_product_checkout_url(@digital_product.slug),
      cancel_url: cancel_product_checkout_url(@digital_product.slug)
    )

    redirect_to session.url, allow_other_host: true
  end

  def check_digital_products_enabled
    return if Current.site&.digital_products_enabled?

    respond_to do |format|
      format.html { redirect_to root_path, alert: t("digital_products.disabled") }
      format.json { render json: { error: t("digital_products.disabled") }, status: :forbidden }
    end
  end
end
