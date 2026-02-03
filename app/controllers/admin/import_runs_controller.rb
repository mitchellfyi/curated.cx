# frozen_string_literal: true

module Admin
  class ImportRunsController < ApplicationController
    include AdminAccess

    PER_PAGE = 50

    # GET /admin/import_runs
    def index
      @import_runs = build_import_runs_scope
      @stats = build_stats
    end

    # GET /admin/import_runs/:id
    def show
      @import_run = ImportRun.includes(:source, :site).find(params[:id])
    end

    private

    def build_import_runs_scope
      scope = ImportRun.recent
                       .includes(source: :site)
                       .page(params[:page])
                       .per(PER_PAGE)

      scope = apply_source_filter(scope)
      scope = apply_status_filter(scope)
      scope = apply_date_filter(scope)
      scope
    end

    def apply_source_filter(scope)
      return scope if params[:source_id].blank?

      @source = Source.find_by(id: params[:source_id])
      return scope unless @source

      scope.where(source_id: @source.id)
    end

    def apply_status_filter(scope)
      return scope if params[:status].blank?
      return scope unless ImportRun.statuses.key?(params[:status])

      scope.where(status: params[:status])
    end

    def apply_date_filter(scope)
      case params[:date_range]
      when "today"
        scope.where("started_at >= ?", Time.current.beginning_of_day)
      when "week"
        scope.where("started_at >= ?", 1.week.ago)
      when "month"
        scope.where("started_at >= ?", 1.month.ago)
      else
        scope
      end
    end

    def build_stats
      # Use a single query with conditional aggregates for efficiency
      base_scope = @source ? ImportRun.where(source: @source) : ImportRun
      day_ago = 24.hours.ago

      result = base_scope.select(
        "COUNT(*) as total",
        "COUNT(*) FILTER (WHERE status = 'completed') as completed",
        "COUNT(*) FILTER (WHERE status = 'failed') as failed",
        "COUNT(*) FILTER (WHERE status = 'running') as running",
        "COUNT(*) FILTER (WHERE started_at > '#{day_ago.to_s(:db)}') as last_24h"
      ).take

      {
        total: result.total.to_i,
        completed: result.completed.to_i,
        failed: result.failed.to_i,
        running: result.running.to_i,
        last_24h: result.last_24h.to_i
      }
    rescue StandardError => e
      Rails.logger.warn("ImportRunsController#build_stats failed: #{e.message}")
      { total: 0, completed: 0, failed: 0, running: 0, last_24h: 0 }
    end
  end
end
