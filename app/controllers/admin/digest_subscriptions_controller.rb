# frozen_string_literal: true

class Admin::DigestSubscriptionsController < ApplicationController
  include AdminAccess

  before_action :set_digest_subscription, only: %i[show update_tags send_test_digest]

  def index
    @digest_subscriptions = DigestSubscription.includes(:user, :subscriber_tags)
                                              .order(created_at: :desc)
                                              .limit(100)

    # Stats for dashboard
    @stats = {
      total: DigestSubscription.count,
      active: DigestSubscription.active.confirmed.count,
      pending: DigestSubscription.pending_confirmation.count,
      weekly: DigestSubscription.weekly.count,
      daily: DigestSubscription.daily.count,
      last_week: DigestSubscription.where("created_at > ?", 1.week.ago).count
    }
  end

  def show
    @subscriber_tags = SubscriberTag.alphabetical
  end

  def update_tags
    tag_ids = Array(params[:tag_ids]).reject(&:blank?).map(&:to_i)
    @digest_subscription.subscriber_tag_ids = tag_ids

    respond_to do |format|
      format.html { redirect_to admin_digest_subscription_path(@digest_subscription), notice: t("admin.digest_subscriptions.tags_updated") }
      format.json { render json: { success: true, tags: @digest_subscription.subscriber_tags.map(&:name) } }
    end
  end

  # Send test digest to a single subscriber (admin testing)
  def send_test_digest
    frequency = params[:frequency] || "weekly"

    if frequency == "weekly"
      DigestMailer.weekly_digest(@digest_subscription).deliver_later
    else
      DigestMailer.daily_digest(@digest_subscription).deliver_later
    end

    redirect_to admin_digest_subscription_path(@digest_subscription),
                notice: t("admin.digest_subscriptions.test_digest_sent", frequency: frequency, email: @digest_subscription.user.email)
  end

  # Trigger sending digest to all due subscribers
  def trigger_digest_send
    frequency = params[:frequency] || "weekly"
    segment_id = params[:segment_id].presence

    SendDigestEmailsJob.perform_later(frequency: frequency, segment_id: segment_id)

    redirect_to admin_digest_subscriptions_path,
                notice: t("admin.digest_subscriptions.digest_send_triggered", frequency: frequency)
  end

  private

  def set_digest_subscription
    @digest_subscription = DigestSubscription.find(params[:id])
  end
end
