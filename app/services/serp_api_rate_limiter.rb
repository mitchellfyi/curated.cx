# frozen_string_literal: true

# Rate limiter for SerpAPI requests using database-backed counting.
# Counts ImportRuns per source within the last hour to enforce rate limits.
# No external dependencies (Redis) required.
class SerpApiRateLimiter
  DEFAULT_RATE_LIMIT_PER_HOUR = 10

  class RateLimitExceeded < StandardError; end

  def initialize(source)
    @source = source
  end

  # Check if a request is allowed under the rate limit
  def allow?
    remaining.positive?
  end

  # Raise an error if rate limit would be exceeded
  def check!
    raise RateLimitExceeded, "Rate limit exceeded for source #{@source.id}: #{used}/#{limit} requests in the last hour" unless allow?

    true
  end

  # Number of requests remaining in the current window
  def remaining
    [ limit - used, 0 ].max
  end

  # Total limit per hour for this source
  def limit
    @source.config["rate_limit_per_hour"] ||
      @source.config[:rate_limit_per_hour] ||
      DEFAULT_RATE_LIMIT_PER_HOUR
  end

  # Number of requests used in the current window (last hour)
  def used
    @source.import_runs.where("started_at > ?", 1.hour.ago).count
  end

  # Time until the oldest request in the window expires (in seconds)
  # Returns 0 if no requests in window
  def reset_in
    oldest_in_window = @source.import_runs
      .where("started_at > ?", 1.hour.ago)
      .order(:started_at)
      .first

    return 0 unless oldest_in_window

    seconds_until_reset = (oldest_in_window.started_at + 1.hour - Time.current).to_i
    [ seconds_until_reset, 0 ].max
  end
end
