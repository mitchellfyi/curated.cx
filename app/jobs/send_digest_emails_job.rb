# frozen_string_literal: true

# Job to send digest emails (daily or weekly) to subscribers.
# Processes subscriptions in batches to avoid memory issues.
#
# Usage:
#   SendDigestEmailsJob.perform_later(frequency: "weekly")
#   SendDigestEmailsJob.perform_later(frequency: "daily", segment_id: 123)
#
class SendDigestEmailsJob < ApplicationJob
  include JobLogging

  queue_as :mailers

  BATCH_SIZE = 100
  VALID_FREQUENCIES = %w[daily weekly].freeze

  def perform(frequency: "weekly", segment_id: nil)
    @frequency = frequency.to_s
    @segment = SubscriberSegment.find_by(id: segment_id) if segment_id

    unless VALID_FREQUENCIES.include?(@frequency)
      log_job_warning("Invalid digest frequency", frequency: @frequency)
      return
    end

    with_job_logging("#{@frequency} digest emails") do
      @stats = { sent: 0, skipped: 0, failed: 0 }
      process_digests
      log_job_info("Digest job completed", **@stats)
    end
  end

  private

  def process_digests
    subscriptions_scope.find_each(batch_size: BATCH_SIZE) do |subscription|
      process_single_subscription(subscription)
    end
  end

  def subscriptions_scope
    base_scope = @frequency == "weekly" ? DigestSubscription.due_for_weekly : DigestSubscription.due_for_daily

    return base_scope unless @segment

    segment_subscriber_ids = SegmentationService.subscribers_for(@segment).pluck(:id)

    if segment_subscriber_ids.empty?
      log_job_warning("Segment has no matching subscribers",
                      segment_id: @segment.id,
                      segment_name: @segment.name)
      return DigestSubscription.none
    end

    base_scope.where(id: segment_subscriber_ids)
  end

  def process_single_subscription(subscription)
    ActsAsTenant.with_tenant(subscription.site.tenant) do
      mailer = build_mailer(subscription)

      if mailer&.message&.present?
        mailer.deliver_later
        subscription.mark_sent!
        @stats[:sent] += 1
      else
        @stats[:skipped] += 1
      end
    end
  rescue StandardError => e
    @stats[:failed] += 1
    log_job_warning("Failed to send digest",
                    subscription_id: subscription.id,
                    user_email: subscription.user&.email,
                    error: e.message)
    # Don't re-raise - continue processing other subscriptions
  end

  def build_mailer(subscription)
    case @frequency
    when "weekly" then DigestMailer.weekly_digest(subscription)
    when "daily" then DigestMailer.daily_digest(subscription)
    end
  end
end
