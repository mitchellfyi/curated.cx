# frozen_string_literal: true

class DigestSubscriptionsController < ApplicationController
  before_action :authenticate_user!, except: [ :unsubscribe, :confirm ]
  skip_after_action :verify_authorized, only: [ :unsubscribe, :confirm ]
  skip_after_action :verify_policy_scoped

  def show
    # Store referral code in session for later use (e.g., if user logs in first)
    session[:referral_code] = params[:ref] if params[:ref].present?

    @subscription = current_user.digest_subscriptions.find_by(site: Current.site)
    authorize(@subscription || DigestSubscription)
  end

  def create
    @subscription = current_user.digest_subscriptions.build(subscription_params)
    @subscription.site = Current.site
    authorize @subscription

    if @subscription.save
      process_referral_attribution
      process_boost_attribution
      redirect_to digest_subscription_path, notice: t("digest_subscriptions.created")
    else
      render :show, status: :unprocessable_entity
    end
  end

  def update
    @subscription = current_user.digest_subscriptions.find_by!(site: Current.site)
    authorize @subscription

    if @subscription.update(subscription_params)
      redirect_to digest_subscription_path, notice: t("digest_subscriptions.updated")
    else
      render :show, status: :unprocessable_entity
    end
  end

  def destroy
    @subscription = current_user.digest_subscriptions.find_by!(site: Current.site)
    authorize @subscription

    @subscription.unsubscribe!
    redirect_to digest_subscription_path, notice: t("digest_subscriptions.unsubscribed")
  end

  # One-click unsubscribe via token (no auth required)
  def unsubscribe
    @subscription = DigestSubscription.find_by!(unsubscribe_token: params[:token])
    @subscription.unsubscribe!

    @site = @subscription.site
    render :unsubscribed
  rescue ActiveRecord::RecordNotFound
    render :unsubscribe_error, status: :not_found
  end

  # Confirm subscription via token (double opt-in)
  def confirm
    @subscription = DigestSubscription.find_by!(confirmation_token: params[:token])
    @subscription.confirm!

    @site = @subscription.site
    render :confirmed
  rescue ActiveRecord::RecordNotFound
    render :confirmation_error, status: :not_found
  end

  # Resend confirmation email
  def resend_confirmation
    @subscription = current_user.digest_subscriptions.find_by(site: Current.site)
    authorize(@subscription || DigestSubscription)

    if @subscription&.pending_confirmation?
      @subscription.resend_confirmation!
      redirect_to digest_subscription_path, notice: t("digest_subscriptions.confirmation_resent")
    else
      redirect_to digest_subscription_path, alert: t("digest_subscriptions.already_confirmed")
    end
  end

  private

  def subscription_params
    params.require(:digest_subscription).permit(:frequency, :active)
  end

  def process_referral_attribution
    referral_code = params[:ref] || session[:referral_code]
    return if referral_code.blank?

    ReferralAttributionService.new(
      referee_subscription: @subscription,
      referral_code: referral_code,
      ip_address: request.remote_ip
    ).attribute!

    # Clear stored referral code from session
    session.delete(:referral_code)
  rescue StandardError => e
    # Log but don't fail subscription creation for referral errors
    Rails.logger.error("Referral attribution failed: #{e.message}")
  end

  def process_boost_attribution
    BoostAttributionService.attribute_conversion(
      subscription: @subscription,
      ip: request.remote_ip
    )
  rescue StandardError => e
    # Log but don't fail subscription creation for boost attribution errors
    Rails.logger.error("Boost attribution failed: #{e.message}")
  end
end
