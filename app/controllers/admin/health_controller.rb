# frozen_string_literal: true

module Admin
  class HealthController < ApplicationController
    include AdminAccess

    # Thresholds for status determination
    FAILED_IMPORTS_WARNING_THRESHOLD = 5
    FLAGS_WARNING_THRESHOLD = 10

    # GET /admin/health
    # Returns JSON health stats for monitoring dashboards
    def show
      health_checks = {
        database: check_database,
        redis: check_redis
      }

      stats = build_stats
      queues = check_queues

      overall_status = determine_status(health_checks, stats)

      render json: {
        status: overall_status,
        timestamp: Time.current.iso8601,
        **health_checks,
        stats: stats,
        queues: queues
      }
    end

    private

    def build_stats
      # Use a single query with multiple counts where possible
      today_start = Time.current.beginning_of_day
      day_ago = 24.hours.ago

      {
        users: safe_count { User.count },
        content_items: safe_count { Entry.feed_items.count },
        content_items_today: safe_count { Entry.feed_items.where("created_at > ?", today_start).count },
        notes: safe_count { Note.count },
        sources_enabled: safe_count { Source.enabled.count },
        imports_running: safe_count { ImportRun.running.count },
        imports_failed_24h: safe_count { ImportRun.failed.where("started_at > ?", day_ago).count },
        editorialisations_pending: safe_count { Editorialisation.by_status("pending").count },
        editorialisations_processing: safe_count { Editorialisation.by_status("processing").count },
        submissions_pending: safe_count { Submission.pending.count },
        flags_open: safe_count { Flag.open.count }
      }
    end

    def safe_count(&block)
      yield
    rescue StandardError => e
      Rails.logger.warn("Health check count failed: #{e.message}")
      -1
    end

    def check_database
      latency = measure_latency { ActiveRecord::Base.connection.execute("SELECT 1") }
      { status: "ok", latency_ms: latency }
    rescue StandardError => e
      Rails.logger.error("Database health check failed: #{e.message}")
      { status: "error", error: e.class.name, message: e.message.truncate(100) }
    end

    def check_redis
      latency = measure_latency { Redis.current.ping }
      { status: "ok", latency_ms: latency }
    rescue StandardError => e
      Rails.logger.warn("Redis health check failed: #{e.message}")
      { status: "unavailable", error: e.class.name }
    end

    def check_queues
      {
        default: safe_count { SolidQueue::Job.where(queue_name: "default").count },
        low: safe_count { SolidQueue::Job.where(queue_name: "low").count },
        high: safe_count { SolidQueue::Job.where(queue_name: "high").count }
      }
    rescue StandardError => e
      Rails.logger.warn("Queue health check failed: #{e.message}")
      { error: e.class.name }
    end

    def determine_status(health_checks, stats)
      # Critical: database or redis down
      if health_checks[:database][:status] != "ok"
        return "critical"
      end

      if health_checks[:redis][:status] == "error"
        return "degraded"
      end

      # Warning: high failure rates or pending issues
      if stats[:imports_failed_24h] > FAILED_IMPORTS_WARNING_THRESHOLD ||
         stats[:flags_open] > FLAGS_WARNING_THRESHOLD
        return "warning"
      end

      "ok"
    end

    def measure_latency
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      yield
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(2)
    end
  end
end
