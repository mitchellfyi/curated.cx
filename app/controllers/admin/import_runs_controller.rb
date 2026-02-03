# frozen_string_literal: true

module Admin
  class ImportRunsController < ApplicationController
    include AdminAccess

    # GET /admin/import_runs
    def index
      @import_runs = ImportRun.recent
                              .includes(:source)
                              .page(params[:page])
                              .per(50)

      # Filter by source if provided
      if params[:source_id].present?
        @import_runs = @import_runs.where(source_id: params[:source_id])
        @source = Source.find(params[:source_id])
      end

      # Filter by status if provided
      if params[:status].present? && ImportRun.statuses.key?(params[:status])
        @import_runs = @import_runs.where(status: params[:status])
      end

      @stats = build_stats
    end

    # GET /admin/import_runs/:id
    def show
      @import_run = ImportRun.includes(:source).find(params[:id])
    end

    private

    def build_stats
      base_scope = @source ? ImportRun.where(source: @source) : ImportRun

      {
        total: base_scope.count,
        completed: base_scope.completed.count,
        failed: base_scope.failed.count,
        running: base_scope.running.count,
        last_24h: base_scope.where("started_at > ?", 24.hours.ago).count
      }
    end
  end
end
