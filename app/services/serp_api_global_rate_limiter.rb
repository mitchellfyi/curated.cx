# frozen_string_literal: true

# Global rate limiter for SerpAPI to enforce monthly API call limits.
# Tracks usage across ALL tenants/sites to stay within plan limits.
#
# Usage:
#   SerpApiGlobalRateLimiter.allow?           # Check if a request is allowed
#   SerpApiGlobalRateLimiter.increment!       # Record a request was made
#   SerpApiGlobalRateLimiter.usage_stats      # Get current usage info
#
class SerpApiGlobalRateLimiter
  # Monthly limit - configure via ENV or default to 1000
  MONTHLY_LIMIT = ENV.fetch("SERP_API_MONTHLY_LIMIT", 1000).to_i

  # Daily soft limit (to spread usage across the month)
  # Default: monthly_limit / 31 ≈ 32/day
  DAILY_SOFT_LIMIT = ENV.fetch("SERP_API_DAILY_LIMIT", (MONTHLY_LIMIT / 31.0).ceil).to_i

  class RateLimitExceeded < StandardError; end

  class << self
    # Check if a request is allowed (hasn't exceeded monthly limit)
    def allow?
      monthly_remaining.positive?
    end

    # Check daily soft limit to spread usage
    def allow_today?
      daily_remaining.positive?
    end

    # Check both limits
    def can_make_request?
      allow? && allow_today?
    end

    # Raise error if request would exceed limits
    def check!
      unless allow?
        raise RateLimitExceeded, "Monthly SerpAPI limit exceeded: #{monthly_used}/#{MONTHLY_LIMIT}"
      end

      unless allow_today?
        Rails.logger.warn("SerpAPI daily soft limit reached: #{daily_used}/#{DAILY_SOFT_LIMIT}. Consider spreading requests.")
      end

      true
    end

    # Record that a SerpAPI request was made
    # This is called AFTER successful API calls
    def increment!
      # ImportRun records are created when jobs run, so we don't need
      # to manually increment - we just count them
      true
    end

    # Monthly usage stats
    def monthly_used
      count_serp_api_runs(start_of_month)
    end

    def monthly_remaining
      [ MONTHLY_LIMIT - monthly_used, 0 ].max
    end

    # Daily usage stats
    def daily_used
      count_serp_api_runs(Time.current.beginning_of_day)
    end

    def daily_remaining
      [ DAILY_SOFT_LIMIT - daily_used, 0 ].max
    end

    # Get full usage stats for monitoring/display
    def usage_stats
      {
        monthly: {
          used: monthly_used,
          limit: MONTHLY_LIMIT,
          remaining: monthly_remaining,
          percent_used: ((monthly_used.to_f / MONTHLY_LIMIT) * 100).round(1)
        },
        daily: {
          used: daily_used,
          soft_limit: DAILY_SOFT_LIMIT,
          remaining: daily_remaining
        },
        projections: {
          days_remaining_in_month: days_remaining_in_month,
          projected_monthly_total: projected_monthly_usage,
          on_track: projected_monthly_usage <= MONTHLY_LIMIT
        }
      }
    end

    private

    def start_of_month
      Time.current.beginning_of_month
    end

    def days_remaining_in_month
      (Time.current.end_of_month.to_date - Time.current.to_date).to_i + 1
    end

    def days_elapsed_in_month
      (Time.current.to_date - Time.current.beginning_of_month.to_date).to_i + 1
    end

    def projected_monthly_usage
      return monthly_used if days_elapsed_in_month >= 28

      daily_average = monthly_used.to_f / days_elapsed_in_month
      (daily_average * Time.current.end_of_month.day).round
    end

    # Count ImportRuns for SerpAPI sources since a given time
    def count_serp_api_runs(since)
      ImportRun.joins(:source)
               .where(sources: { kind: serp_api_kinds })
               .where("import_runs.started_at >= ?", since)
               .count
    end

    def serp_api_kinds
      Source.kinds.slice(:serp_api_google_news, :serp_api_google_jobs).values
    end
  end
end
