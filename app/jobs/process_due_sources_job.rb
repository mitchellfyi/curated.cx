# frozen_string_literal: true

# Recurring job that finds all sources due for execution and enqueues
# the appropriate ingestion job for each source type.
class ProcessDueSourcesJob < ApplicationJob
  queue_as :default

  # Map source kinds to their ingestion job classes
  JOB_MAPPING = {
    "serp_api_google_news" => SerpApiIngestionJob,
    "rss" => FetchRssJob,
    "serp_api_google_jobs" => SerpApiJobsIngestionJob,
    "serp_api_youtube" => SerpApiYoutubeIngestionJob,
    "hacker_news" => HackerNewsIngestionJob,
    "product_hunt" => ProductHuntIngestionJob,
    "google_scholar" => SerpApiGoogleScholarIngestionJob,
    "reddit_search" => SerpApiRedditIngestionJob,
    "amazon_search" => SerpApiAmazonIngestionJob,
    "google_shopping" => SerpApiGoogleShoppingIngestionJob
  }.freeze

  def perform
    Source.enabled.due_for_run.find_each do |source|
      next unless source.run_due?

      enqueue_job_for_source(source)
    end
  end

  private

  def enqueue_job_for_source(source)
    job_class = JOB_MAPPING[source.kind]

    if job_class.nil?
      log_job_info("No job mapping for source kind",
                   source_kind: source.kind, source_id: source.id)
      return
    end

    job_class.perform_later(source.id)
  rescue StandardError => e
    log_job_error(e, source_id: source.id, source_kind: source.kind)
  end
end
