# frozen_string_literal: true

module Admin
  class BusinessSubscriptionsController < ApplicationController
    include AdminAccess

    before_action :set_subscription, only: %i[show cancel]

    def index
      @subscriptions = BusinessSubscription.joins(:entry)
                                            .where(entries: { site_id: Current.site&.id })
                                            .includes(:entry, :user)
                                            .recent
                                            .page(params[:page]).per(25)

      @subscriptions = @subscriptions.where(tier: params[:tier]) if params[:tier].present?
      @subscriptions = @subscriptions.where(status: params[:status]) if params[:status].present?

      calculate_stats
    end

    def show
    end

    def cancel
      @subscription.cancel!
      redirect_to admin_business_subscription_path(@subscription), notice: "Subscription cancelled."
    end

    private

    def set_subscription
      @subscription = BusinessSubscription.joins(:entry)
                                           .where(entries: { site_id: Current.site&.id })
                                           .includes(:entry, :user)
                                           .find(params[:id])
    end

    def calculate_stats
      scope = BusinessSubscription.joins(:entry).where(entries: { site_id: Current.site&.id })
      @total_subscriptions = scope.count
      @active_subscriptions = scope.active.count
      @pro_subscriptions = scope.pro.count
      @premium_subscriptions = scope.premium.count
    end
  end
end
