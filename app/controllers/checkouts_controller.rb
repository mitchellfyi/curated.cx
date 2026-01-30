# frozen_string_literal: true

# Controller for initiating Stripe Checkout sessions.
#
# Routes:
#   GET  /listings/:listing_id/checkout/new - Show checkout options
#   POST /listings/:listing_id/checkout     - Create checkout session
#   GET  /listings/:listing_id/checkout/success - Payment success page
#   GET  /listings/:listing_id/checkout/cancel  - Payment cancelled page
#
class CheckoutsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_listing
  before_action :authorize_checkout

  # GET /listings/:listing_id/checkout/new
  def new
    @checkout_options = available_checkout_options
  end

  # POST /listings/:listing_id/checkout
  def create
    checkout_type = params[:checkout_type]&.to_sym

    unless valid_checkout_type?(checkout_type)
      redirect_to new_listing_checkout_path(@listing), alert: t("checkouts.invalid_type")
      return
    end

    service = StripeCheckoutService.new(@listing, checkout_type: checkout_type)
    session = service.create_session(
      success_url: listing_checkout_success_url(@listing, session_id: "{CHECKOUT_SESSION_ID}"),
      cancel_url: listing_checkout_cancel_url(@listing)
    )

    redirect_to session.url, allow_other_host: true
  rescue StripeCheckoutService::StripeNotConfiguredError
    redirect_to new_listing_checkout_path(@listing), alert: t("checkouts.stripe_not_configured")
  rescue Stripe::StripeError => e
    Rails.logger.error("Stripe error: #{e.message}")
    redirect_to new_listing_checkout_path(@listing), alert: t("checkouts.payment_error")
  end

  # GET /listings/:listing_id/checkout/success
  def success
    session_id = params[:session_id]

    if session_id.present? && @listing.stripe_checkout_session_id == session_id
      flash.now[:notice] = t("checkouts.success")
    end
  end

  # GET /listings/:listing_id/checkout/cancel
  def cancel
    flash.now[:alert] = t("checkouts.cancelled")
  end

  private

  def set_listing
    @listing = Listing.find(params[:listing_id])
  end

  def authorize_checkout
    authorize @listing, :checkout?
  end

  def available_checkout_options
    options = []

    # Job posting options (only for job listings)
    if @listing.job?
      options += [
        { type: :job_post_30, config: StripeCheckoutService::PRICE_CONFIGS[:job_post_30] },
        { type: :job_post_60, config: StripeCheckoutService::PRICE_CONFIGS[:job_post_60] },
        { type: :job_post_90, config: StripeCheckoutService::PRICE_CONFIGS[:job_post_90] }
      ]
    end

    # Featured options (for any listing)
    options += [
      { type: :featured_7, config: StripeCheckoutService::PRICE_CONFIGS[:featured_7] },
      { type: :featured_14, config: StripeCheckoutService::PRICE_CONFIGS[:featured_14] },
      { type: :featured_30, config: StripeCheckoutService::PRICE_CONFIGS[:featured_30] }
    ]

    options
  end

  def valid_checkout_type?(type)
    StripeCheckoutService::PRICE_CONFIGS.key?(type)
  end
end
