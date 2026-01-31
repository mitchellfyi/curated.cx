# frozen_string_literal: true

class SendDigestEmailsJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 100

  def perform(frequency: "weekly", segment_id: nil)
    @segment = segment_id.present? ? SubscriberSegment.find_by(id: segment_id) : nil

    case frequency.to_s
    when "weekly"
      send_weekly_digests
    when "daily"
      send_daily_digests
    else
      Rails.logger.warn("Unknown digest frequency: #{frequency}")
    end
  end

  private

  def send_weekly_digests
    subscriptions_scope(:weekly).find_each(batch_size: BATCH_SIZE) do |subscription|
      send_digest(subscription, :weekly)
    end
  end

  def send_daily_digests
    subscriptions_scope(:daily).find_each(batch_size: BATCH_SIZE) do |subscription|
      send_digest(subscription, :daily)
    end
  end

  def subscriptions_scope(frequency)
    base_scope = frequency == :weekly ? DigestSubscription.due_for_weekly : DigestSubscription.due_for_daily

    if @segment
      segment_subscriber_ids = SegmentationService.subscribers_for(@segment).pluck(:id)

      if segment_subscriber_ids.empty?
        Rails.logger.warn("Segment '#{@segment.name}' (id: #{@segment.id}) has no matching subscribers")
        return DigestSubscription.none
      end

      base_scope.where(id: segment_subscriber_ids)
    else
      base_scope
    end
  end

  def send_digest(subscription, frequency)
    ActsAsTenant.with_tenant(subscription.site.tenant) do
      mailer = case frequency
      when :weekly then DigestMailer.weekly_digest(subscription)
      when :daily then DigestMailer.daily_digest(subscription)
      end

      # deliver_later returns nil if the mailer action returns early (no content)
      if mailer&.message&.present?
        mailer.deliver_later
        subscription.mark_sent!
      end
    end
  rescue StandardError => e
    Rails.logger.error("Failed to send #{frequency} digest to #{subscription.user.email}: #{e.message}")
    # Don't mark as sent on failure - will retry next time
  end
end
