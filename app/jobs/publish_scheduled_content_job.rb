# frozen_string_literal: true

class PublishScheduledContentJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 100

  def perform
    publish_content_items
    publish_listings
  end

  private

  def publish_content_items
    ContentItem.due_for_publishing.find_each(batch_size: BATCH_SIZE) do |content_item|
      publish_item(content_item, "ContentItem")
    end
  end

  def publish_listings
    Listing.due_for_publishing.find_each(batch_size: BATCH_SIZE) do |listing|
      publish_item(listing, "Listing")
    end
  end

  def publish_item(item, type)
    ActsAsTenant.with_tenant(item.site.tenant) do
      item.update!(published_at: Time.current, scheduled_for: nil)
      Rails.logger.info("Published scheduled #{type} #{item.id}: #{item.title}")
    end
  rescue StandardError => e
    Rails.logger.error("Failed to publish scheduled #{type} #{item.id}: #{e.message}")
  end
end
