# frozen_string_literal: true

class Admin::BoostPayoutsController < ApplicationController
  include AdminAccess

  before_action :set_payout, only: [ :show, :update ]

  def index
    @payouts = BoostPayout.where(site: Current.site)
                          .order(period_start: :desc)
                          .limit(50)

    @stats = calculate_stats
  end

  def show
  end

  def update
    if params[:mark_paid] && @payout.pending?
      @payout.mark_paid!(params[:payment_reference])
      redirect_to admin_boost_payout_path(@payout), notice: t("admin.boost_payouts.marked_paid")
    elsif params[:cancel] && @payout.pending?
      @payout.cancel!
      redirect_to admin_boost_payout_path(@payout), notice: t("admin.boost_payouts.cancelled")
    else
      redirect_to admin_boost_payout_path(@payout), alert: t("admin.boost_payouts.cannot_update")
    end
  end

  private

  def set_payout
    @payout = BoostPayout.where(site: Current.site).find(params[:id])
  end

  def calculate_stats
    payouts = BoostPayout.where(site: Current.site)
    {
      total_payouts: payouts.count,
      pending_count: payouts.pending.count,
      pending_amount: payouts.pending.sum(:amount) || 0,
      paid_count: payouts.paid.count,
      paid_amount: payouts.paid.sum(:amount) || 0,
      total_earned: payouts.where(status: [ :pending, :paid ]).sum(:amount) || 0
    }
  end
end
