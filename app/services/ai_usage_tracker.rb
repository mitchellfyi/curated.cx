# frozen_string_literal: true

# Global tracker for AI API usage (similar to SerpApiGlobalRateLimiter).
# Tracks token usage, costs, and enforces limits.
#
# Usage:
#   AiUsageTracker.track!(tokens_in: 500, tokens_out: 200, model: "gpt-4o-mini", tenant: tenant)
#   AiUsageTracker.usage_stats
#   AiUsageTracker.allow?
#
class AiUsageTracker
  # Default limits - configure via ENV
  MONTHLY_TOKEN_LIMIT = ENV.fetch("AI_MONTHLY_TOKEN_LIMIT", 10_000_000).to_i
  DAILY_SOFT_LIMIT = ENV.fetch("AI_DAILY_TOKEN_LIMIT", (MONTHLY_TOKEN_LIMIT / 31.0).ceil).to_i

  # Cost per 1M tokens (in cents) - update as pricing changes
  MODEL_COSTS = {
    "gpt-4o-mini" => { input: 15, output: 60 },      # $0.15/$0.60 per 1M
    "gpt-4o" => { input: 250, output: 1000 },        # $2.50/$10.00 per 1M
    "gpt-4-turbo" => { input: 1000, output: 3000 },  # $10/$30 per 1M
    "claude-3-haiku" => { input: 25, output: 125 },  # $0.25/$1.25 per 1M
    "claude-3-sonnet" => { input: 300, output: 1500 }, # $3/$15 per 1M
    "default" => { input: 15, output: 60 }           # Default to cheapest
  }.freeze

  class RateLimitExceeded < StandardError; end

  class << self
    # Track a completed AI request
    def track!(tokens_in:, tokens_out:, model:, editorialisation: nil, tenant: nil)
      cost_cents = calculate_cost(tokens_in, tokens_out, model)

      if editorialisation
        editorialisation.update!(
          input_tokens: tokens_in,
          output_tokens: tokens_out,
          estimated_cost_cents: cost_cents
        )
      end

      Rails.logger.info(
        "[AiUsageTracker] Tracked: in=#{tokens_in} out=#{tokens_out} " \
        "model=#{model} cost=#{cost_cents}¢ tenant=#{tenant&.id || 'global'}"
      )

      { tokens_in: tokens_in, tokens_out: tokens_out, cost_cents: cost_cents }
    end

    # Check if we're within limits
    def allow?
      monthly_remaining.positive?
    end

    def allow_today?
      daily_remaining.positive?
    end

    def can_make_request?
      allow? && allow_today?
    end

    # Raise if over limit
    def check!
      unless allow?
        raise RateLimitExceeded, "Monthly AI token limit exceeded: #{monthly_used}/#{MONTHLY_TOKEN_LIMIT}"
      end

      unless allow_today?
        Rails.logger.warn("AI daily soft limit reached: #{daily_used}/#{DAILY_SOFT_LIMIT}")
      end

      true
    end

    # Estimate cost in cents for a given number of tokens
    def estimate_cost(input_tokens:, output_tokens:, model: "default")
      calculate_cost(input_tokens, output_tokens, model)
    end

    # Usage stats (global or per-tenant)
    def usage_stats(tenant: nil)
      {
        monthly: {
          used: monthly_used(tenant),
          limit: MONTHLY_TOKEN_LIMIT,
          remaining: monthly_remaining(tenant),
          percent_used: ((monthly_used(tenant).to_f / MONTHLY_TOKEN_LIMIT) * 100).round(1)
        },
        daily: {
          used: daily_used(tenant),
          soft_limit: DAILY_SOFT_LIMIT,
          remaining: daily_remaining(tenant)
        },
        costs: {
          monthly_cents: monthly_cost(tenant),
          daily_cents: daily_cost(tenant),
          monthly_dollars: (monthly_cost(tenant) / 100.0).round(2)
        },
        projections: {
          days_remaining_in_month: days_remaining_in_month,
          projected_monthly_tokens: projected_monthly_usage(tenant),
          projected_monthly_cost_cents: projected_monthly_cost(tenant),
          on_track: projected_monthly_usage(tenant) <= MONTHLY_TOKEN_LIMIT
        },
        breakdown: usage_breakdown(tenant)
      }
    end

    # Token usage methods
    def monthly_used(tenant = nil)
      scope = editorialisation_scope(tenant).where("created_at >= ?", start_of_month)
      (scope.sum(:input_tokens) || 0) + (scope.sum(:output_tokens) || 0)
    end

    def monthly_remaining(tenant = nil)
      [ MONTHLY_TOKEN_LIMIT - monthly_used(tenant), 0 ].max
    end

    def daily_used(tenant = nil)
      scope = editorialisation_scope(tenant).where("created_at >= ?", Time.current.beginning_of_day)
      (scope.sum(:input_tokens) || 0) + (scope.sum(:output_tokens) || 0)
    end

    def daily_remaining(tenant = nil)
      [ DAILY_SOFT_LIMIT - daily_used(tenant), 0 ].max
    end

    # Cost methods
    def monthly_cost(tenant = nil)
      editorialisation_scope(tenant)
        .where("created_at >= ?", start_of_month)
        .sum(:estimated_cost_cents) || 0
    end

    def daily_cost(tenant = nil)
      editorialisation_scope(tenant)
        .where("created_at >= ?", Time.current.beginning_of_day)
        .sum(:estimated_cost_cents) || 0
    end

    private

    def editorialisation_scope(tenant)
      scope = Editorialisation.completed
      scope = scope.where(site: tenant.sites) if tenant
      scope
    end

    def calculate_cost(tokens_in, tokens_out, model)
      costs = MODEL_COSTS[model] || MODEL_COSTS["default"]

      input_cost = (tokens_in.to_f / 1_000_000) * costs[:input] * 100  # cents
      output_cost = (tokens_out.to_f / 1_000_000) * costs[:output] * 100

      (input_cost + output_cost).round
    end

    def start_of_month
      Time.current.beginning_of_month
    end

    def days_remaining_in_month
      (Time.current.end_of_month.to_date - Time.current.to_date).to_i + 1
    end

    def days_elapsed_in_month
      (Time.current.to_date - Time.current.beginning_of_month.to_date).to_i + 1
    end

    def projected_monthly_usage(tenant)
      return monthly_used(tenant) if days_elapsed_in_month >= 28

      daily_average = monthly_used(tenant).to_f / days_elapsed_in_month
      (daily_average * Time.current.end_of_month.day).round
    end

    def projected_monthly_cost(tenant)
      return monthly_cost(tenant) if days_elapsed_in_month >= 28

      daily_average = monthly_cost(tenant).to_f / days_elapsed_in_month
      (daily_average * Time.current.end_of_month.day).round
    end

    def usage_breakdown(tenant)
      scope = editorialisation_scope(tenant).where("created_at >= ?", start_of_month)

      {
        by_status: scope.unscoped.where("created_at >= ?", start_of_month).group(:status).count,
        by_model: scope.group(:ai_model).sum(:input_tokens).transform_values { |v| v || 0 },
        total_requests: scope.count,
        avg_tokens_per_request: scope.count.positive? ? (monthly_used(tenant).to_f / scope.count).round : 0
      }
    end
  end
end
