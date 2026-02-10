# frozen_string_literal: true

# Processes accumulated backlog after a workflow is resumed.
# Enqueues jobs for items that were skipped during the pause period.
#
class ProcessBacklogJob < ApplicationJob
  queue_as :low

  def perform(workflow_type:, tenant_id: nil, source_id: nil, subtype: nil)
    tenant = Tenant.find_by(id: tenant_id)
    source = Source.find_by(id: source_id)

    case workflow_type
    when "imports"
      process_import_backlog(tenant: tenant, source: source, subtype: subtype)
    when "ai_processing"
      process_ai_backlog(tenant: tenant)
    else
      Rails.logger.warn("[ProcessBacklogJob] Unknown workflow type: #{workflow_type}")
    end
  end

  private

  def process_import_backlog(tenant:, source:, subtype:)
    sources_scope = Source.enabled

    if source
      # Just run this specific source
      sources_scope = sources_scope.where(id: source.id)
    elsif tenant
      sources_scope = sources_scope.where(tenant: tenant)
    end

    # Filter by subtype if specified
    if subtype.present? && subtype != "all"
      sources_scope = sources_scope.where(kind: subtype)
    end

    # Queue import jobs for each source
    sources_scope.find_each do |src|
      case src.kind
      when "rss"
        FetchRssJob.perform_later(src.id)
      when "serp_api_google_news"
        SerpApiIngestionJob.perform_later(src.id)
      when "serp_api_google_jobs"
        SerpApiJobsIngestionJob.perform_later(src.id)
      when "serp_api_youtube"
        SerpApiYoutubeIngestionJob.perform_later(src.id)
      end
    end

    Rails.logger.info(
      "[ProcessBacklogJob] Queued #{sources_scope.count} import jobs " \
      "for tenant=#{tenant&.id || 'all'} subtype=#{subtype || 'all'}"
    )
  end

  def process_ai_backlog(tenant:)
    scope = Entry.feed_items.published
      .where(editorialised_at: nil)
      .joins(:source)
      .where(sources: { editorialisation_enabled: true })

    scope = scope.where(sources: { tenant: tenant }) if tenant

    count = 0
    scope.order(created_at: :desc).limit(500).find_each do |entry|
      EditorialiseEntryJob.perform_later(entry.id)
      count += 1
    end

    Rails.logger.info(
      "[ProcessBacklogJob] Queued #{count} editorialisation jobs for tenant=#{tenant&.id || 'all'}"
    )
  end
end
