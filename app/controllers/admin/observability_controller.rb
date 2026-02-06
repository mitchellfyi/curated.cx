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
      @ai_usage_stats = AiUsageTracker.usage_stats
      @active_pauses = WorkflowPause.active.recent.limit(5).includes(:tenant, :source, :paused_by)
      @pause_status = WorkflowPauseService.status_summary
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
      @is_paused = WorkflowPauseService.paused?(:imports, subtype: "serp_api_google_news")
      @active_pauses = WorkflowPause.active.for_workflow("imports")
    end

    # GET /admin/observability/ai_usage
    def ai_usage
      @stats = AiUsageTracker.usage_stats
      @is_paused = WorkflowPauseService.paused?(:ai_processing)
      @active_pauses = WorkflowPause.active.for_workflow("ai_processing")
      @active_pause = @active_pauses.first
      @daily_usage = build_ai_daily_usage_chart
      @recent_editorialisations = Editorialisation.completed
                                                  .recent
                                                  .includes(:content_item, :site)
                                                  .limit(50)
    end

    private

    def build_ai_daily_usage_chart
      # Last 30 days of AI usage
      Editorialisation.completed
                      .where("created_at > ?", 30.days.ago)
                      .group("DATE(created_at)")
                      .select(
                        "DATE(created_at) as date",
                        "COUNT(*) as count",
                        "SUM(tokens_used) as total_tokens",
                        "SUM(estimated_cost_cents) as total_cost"
                      )
                      .order("date")
                      .map do |row|
                        {
                          date: row.date.to_s,
                          count: row.count,
                          tokens: row.total_tokens || 0,
                          cost_cents: row.total_cost || 0
                        }
                      end
    end

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
      # Build status counts with string keys
      status_counts = Editorialisation.where("created_at > ?", 24.hours.ago)
                                      .group(:status).count
                                      .transform_keys do |k|
                                        # Handle both integer enum values and string status names
                                        if k.is_a?(Integer)
                                          Editorialisation.statuses.key(k) || k.to_s
                                        else
                                          k.to_s
                                        end
                                      end
      {
        total_24h: Editorialisation.where("created_at > ?", 24.hours.ago).count,
        by_status: status_counts,
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
      return 0 unless solid_queue_available?

      SolidQueue::Job.where(finished_at: nil).count
    rescue StandardError
      0
    end

    def solid_queue_failed_count
      return 0 unless solid_queue_available?

      SolidQueue::FailedExecution.count
    rescue StandardError
      0
    end

    def solid_queue_available?
      return @solid_queue_available if defined?(@solid_queue_available)

      @solid_queue_available = defined?(SolidQueue) &&
                               ActiveRecord::Base.connection.table_exists?("solid_queue_jobs")
    rescue StandardError
      @solid_queue_available = false
    end
  end
end
