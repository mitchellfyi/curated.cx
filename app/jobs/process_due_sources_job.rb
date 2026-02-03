# frozen_string_literal: true

# Recurring job that finds all sources due for execution and enqueues
# the appropriate ingestion job for each source type.
class ProcessDueSourcesJob < ApplicationJob
  queue_as :default

  # Map source kinds to their ingestion job classes
  JOB_MAPPING = {
    "serp_api_google_news" => SerpApiIngestionJob,
    "rss" => FetchRssJob
  }.freeze

  def perform
    Source.enabled.due_for_run.find_each do |source|
      enqueue_job_for_source(source)
    end
  end

  private

  def enqueue_job_for_source(source)
    job_class = JOB_MAPPING[source.kind]

    if job_class.nil?
      Rails.logger.info("ProcessDueSourcesJob: No job mapping for source kind '#{source.kind}' (source_id: #{source.id})")
      return
    end

    job_class.perform_later(source.id)
  rescue StandardError => e
    Rails.logger.error(
      "ProcessDueSourcesJob: Failed to enqueue job for source #{source.id}: #{e.message}"
    )
  end
end
