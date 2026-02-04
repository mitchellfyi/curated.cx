# frozen_string_literal: true

module Admin
  class ObservabilityController < ApplicationController
    include AdminAccess

    # GET /admin/observability
    def show
      @stats = build_overview_stats
      @recent_import_runs = ImportRun.recent.includes(:source).limit(10)
      @recent_editorialisations = Editorialisation.recent.includes(:content_item).limit(10)
      @serp_api_stats = SerpApiGlobalRateLimiter.usage_stats
    end

    # GET /admin/observability/imports
    def imports
      @sources = Source.enabled.includes(:site).order(:name)
      @import_runs = ImportRun.recent.includes(:source).page(params[:page]).per(50)
      @stats = build_import_stats
    end

    # GET /admin/observability/editorialisations
    def editorialisations
      @editorialisations = Editorialisation.recent.includes(:content_item, :site).page(params[:page]).per(50)
      @stats = build_editorialisation_stats
    end

    # GET /admin/observability/serp_api
    def serp_api
      @stats = SerpApiGlobalRateLimiter.usage_stats
      @sources = Source.where(kind: serp_api_kinds).includes(:site).order(:name)
      @recent_runs = ImportRun.joins(:source)
                              .where(sources: { kind: serp_api_kinds })
                              .recent
                              .includes(:source)
                              .limit(50)
      @daily_usage = build_daily_usage_chart
    end

    private

    def build_overview_stats
      {
        # Import stats
        total_sources: Source.enabled.count,
        active_sources_today: Source.enabled
                                    .joins(:import_runs)
                                    .where("import_runs.started_at > ?", Time.current.beginning_of_day)
                                    .distinct.count,
        imports_today: ImportRun.where("started_at > ?", Time.current.beginning_of_day).count,
        failed_imports_today: ImportRun.failed
                                       .where("started_at > ?", Time.current.beginning_of_day).count,
        items_imported_today: ImportRun.where("started_at > ?", Time.current.beginning_of_day)
                                       .sum(:items_created),

        # Editorialisation stats
        editorialisations_today: Editorialisation.where("created_at > ?", Time.current.beginning_of_day).count,
        editorialisations_completed: Editorialisation.completed
                                                     .where("created_at > ?", Time.current.beginning_of_day).count,
        editorialisations_failed: Editorialisation.failed
                                                  .where("created_at > ?", Time.current.beginning_of_day).count,
        editorialisations_pending: Editorialisation.pending.count,

        # Content stats
        content_items_total: ContentItem.count,
        content_items_published: ContentItem.published.count,
        content_items_editorialised: ContentItem.where.not(editorialised_at: nil).count,

        # Background jobs (from SolidQueue if available)
        jobs_pending: solid_queue_pending_count,
        jobs_failed: solid_queue_failed_count
      }
    end

    def build_import_stats
      {
        total_runs_24h: ImportRun.where("started_at > ?", 24.hours.ago).count,
        completed_24h: ImportRun.completed.where("started_at > ?", 24.hours.ago).count,
        failed_24h: ImportRun.failed.where("started_at > ?", 24.hours.ago).count,
        items_created_24h: ImportRun.where("started_at > ?", 24.hours.ago).sum(:items_created),
        items_updated_24h: ImportRun.where("started_at > ?", 24.hours.ago).sum(:items_updated),
        items_failed_24h: ImportRun.where("started_at > ?", 24.hours.ago).sum(:items_failed),
        avg_duration_ms: ImportRun.completed
                                  .where("started_at > ?", 24.hours.ago)
                                  .where.not(completed_at: nil)
                                  .average("EXTRACT(EPOCH FROM (completed_at - started_at)) * 1000")
                                  &.round || 0,
        sources_by_status: Source.group(:last_status).count
      }
    end

    def build_editorialisation_stats
      {
        total_24h: Editorialisation.where("created_at > ?", 24.hours.ago).count,
        by_status: Editorialisation.where("created_at > ?", 24.hours.ago)
                                   .group(:status).count
                                   .transform_keys { |k| Editorialisation.statuses.key(k) },
        avg_tokens: Editorialisation.completed
                                    .where("created_at > ?", 24.hours.ago)
                                    .average(:tokens_used)&.round || 0,
        avg_duration_ms: Editorialisation.completed
                                         .where("created_at > ?", 24.hours.ago)
                                         .average(:duration_ms)&.round || 0,
        total_tokens_24h: Editorialisation.completed
                                          .where("created_at > ?", 24.hours.ago)
                                          .sum(:tokens_used),
        pending_content_items: ContentItem.published
                                          .where(editorialised_at: nil)
                                          .joins(:source)
                                          .where(sources: { editorialisation_enabled: true })
                                          .count
      }
    end

    def build_daily_usage_chart
      # Last 30 days of SerpAPI usage
      ImportRun.joins(:source)
               .where(sources: { kind: serp_api_kinds })
               .where("import_runs.started_at > ?", 30.days.ago)
               .group("DATE(import_runs.started_at)")
               .count
               .transform_keys { |k| k.to_s }
    end

    def serp_api_kinds
      Source.kinds.slice(:serp_api_google_news, :serp_api_google_jobs, :serp_api_youtube).values
    end

    def solid_queue_pending_count
      SolidQueue::Job.where(finished_at: nil).count
    rescue
      0
    end

    def solid_queue_failed_count
      SolidQueue::FailedExecution.count
    rescue
      0
    end
  end
end
