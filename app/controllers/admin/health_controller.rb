# frozen_string_literal: true

module Admin
  class HealthController < ApplicationController
    include AdminAccess

    # GET /admin/health
    # Returns JSON health stats for monitoring dashboards
    def show
      stats = {
        status: "ok",
        timestamp: Time.current.iso8601,
        database: check_database,
        redis: check_redis,
        stats: {
          users: User.count,
          content_items: ContentItem.count,
          content_items_today: ContentItem.where("created_at > ?", Time.current.beginning_of_day).count,
          notes: Note.count,
          sources_enabled: Source.enabled.count,
          imports_running: ImportRun.running.count,
          imports_failed_24h: ImportRun.failed.where("started_at > ?", 24.hours.ago).count,
          editorialisations_pending: Editorialisation.by_status("pending").count,
          editorialisations_processing: Editorialisation.by_status("processing").count,
          submissions_pending: Submission.pending.count,
          flags_open: Flag.open.count
        },
        queues: check_queues
      }

      # Overall status
      stats[:status] = "degraded" if stats[:database][:status] != "ok" || stats[:redis][:status] != "ok"
      stats[:status] = "warning" if stats[:stats][:imports_failed_24h] > 5 || stats[:stats][:flags_open] > 10

      render json: stats
    end

    private

    def check_database
      ActiveRecord::Base.connection.execute("SELECT 1")
      { status: "ok", latency_ms: measure_latency { ActiveRecord::Base.connection.execute("SELECT 1") } }
    rescue => e
      { status: "error", error: e.message }
    end

    def check_redis
      Redis.current.ping
      { status: "ok", latency_ms: measure_latency { Redis.current.ping } }
    rescue => e
      { status: "error", error: e.message }
    end

    def check_queues
      {
        default: Solid::Queue::Job.where(queue_name: "default").count,
        low: Solid::Queue::Job.where(queue_name: "low").count,
        high: Solid::Queue::Job.where(queue_name: "high").count
      }
    rescue => e
      { error: e.message }
    end

    def measure_latency
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      yield
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(2)
    end
  end
end
