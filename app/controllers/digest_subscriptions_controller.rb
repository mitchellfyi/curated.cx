# frozen_string_literal: true

class DigestSubscriptionsController < ApplicationController
  before_action :authenticate_user!, except: [ :unsubscribe ]
  skip_after_action :verify_authorized, only: [ :unsubscribe ]
  skip_after_action :verify_policy_scoped

  def show
    @subscription = current_user.digest_subscriptions.find_by(site: Current.site)
    authorize(@subscription || DigestSubscription)
  end

  def create
    @subscription = current_user.digest_subscriptions.build(subscription_params)
    @subscription.site = Current.site
    authorize @subscription

    if @subscription.save
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

  private

  def subscription_params
    params.require(:digest_subscription).permit(:frequency, :active)
  end
end
