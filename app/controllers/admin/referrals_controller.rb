# frozen_string_literal: true

class Admin::ReferralsController < ApplicationController
  include AdminAccess

  before_action :set_referral, only: [ :show, :update  ]

  def index
    @referrals = Referral
                         .includes(referrer_subscription: :user, referee_subscription: :user)
                         .order(created_at: :desc)
                         .limit(100)

    @stats = calculate_stats
  end

  def show
  end

  def update
    if params[:mark_rewarded] && @referral.confirmed?
      @referral.mark_rewarded!
      redirect_to admin_referral_path(@referral), notice: t("admin.referrals.marked_rewarded")
    else
      redirect_to admin_referral_path(@referral), alert: t("admin.referrals.cannot_update")
    end
  end

  private

  def set_referral
    @referral = Referral.find(params[:id])
  end

  def calculate_stats
    referrals = Referral
    {
      total: referrals.count,
      pending: referrals.pending.count,
      confirmed: referrals.confirmed.count,
      rewarded: referrals.rewarded.count,
      cancelled: referrals.cancelled.count,
      conversion_rate: calculate_conversion_rate(referrals),
      top_referrers: top_referrers
    }
  end

  def calculate_conversion_rate(referrals)
    total = referrals.count
    return 0 if total.zero?

    confirmed = referrals.where(status: [ :confirmed, :rewarded ]).count
    ((confirmed.to_f / total) * 100).round(1)
  end

  def top_referrers
    DigestSubscription
                      .joins(:referrals_as_referrer)
                      .where(referrals: { status: [ :confirmed, :rewarded ] })
                      .group("digest_subscriptions.id")
                      .select("digest_subscriptions.*, COUNT(referrals.id) as referral_count")
                      .order("referral_count DESC")
                      .limit(10)
                      .includes(:user)
  end
end
