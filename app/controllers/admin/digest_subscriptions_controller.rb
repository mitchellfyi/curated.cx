# frozen_string_literal: true

class Admin::DigestSubscriptionsController < ApplicationController
  include AdminAccess

  before_action :set_digest_subscription, only: %i[show update_tags]

  def index
    @digest_subscriptions = DigestSubscription.includes(:user, :subscriber_tags)
                                              .order(created_at: :desc)
                                              .limit(100)
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

  private

  def set_digest_subscription
    @digest_subscription = DigestSubscription.find(params[:id])
  end
end
