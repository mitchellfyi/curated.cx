# frozen_string_literal: true

# Tracks AI (LLM) usage across the platform for cost monitoring and limits.
# Similar to SerpApiGlobalRateLimiter but for AI/editorialisation costs.
#
# Usage:
#   AiUsageTracker.allow?                    # Check if a request is allowed
#   AiUsageTracker.track!(input: 100, output: 50, cost_cents: 2, site: site)
#   AiUsageTracker.usage_stats               # Get current usage info
#   AiUsageTracker.usage_stats(tenant: t)    # Get tenant-specific stats
#
class AiUsageTracker
  # Monthly cost limit in cents - configure via ENV
  MONTHLY_COST_LIMIT_CENTS = ENV.fetch("AI_MONTHLY_COST_LIMIT_CENTS", 10_000).to_i # $100 default

  # Daily soft limit (to spread usage across the month)
  DAILY_COST_SOFT_LIMIT_CENTS = ENV.fetch("AI_DAILY_COST_LIMIT_CENTS", (MONTHLY_COST_LIMIT_CENTS / 31.0).ceil).to_i

  # Token limits (secondary protection)
  MONTHLY_TOKEN_LIMIT = ENV.fetch("AI_MONTHLY_TOKEN_LIMIT", 1_000_000).to_i
  DAILY_TOKEN_SOFT_LIMIT = ENV.fetch("AI_DAILY_TOKEN_LIMIT", (MONTHLY_TOKEN_LIMIT / 31.0).ceil).to_i

  # Cost per 1000 tokens (in cents) - rough estimates, adjust based on model
  # These are Claude 3 Sonnet pricing estimates
  INPUT_COST_PER_1K = ENV.fetch("AI_INPUT_COST_PER_1K_CENTS", 0.3).to_f   # $0.003/1K
  OUTPUT_COST_PER_1K = ENV.fetch("AI_OUTPUT_COST_PER_1K_CENTS", 1.5).to_f # $0.015/1K

  class CostLimitExceeded < StandardError; end

  class << self
    # Check if an AI request is allowed (hasn't exceeded monthly limit)
    def allow?
      monthly_cost_remaining.positive? && monthly_tokens_remaining.positive?
    end

    # Check daily soft limit to spread usage
    def allow_today?
      daily_cost_remaining.positive? && daily_tokens_remaining.positive?
    end

    # Check both limits
    def can_make_request?
      allow? && allow_today?
    end

    # Raise error if request would exceed limits
    def check!
      unless allow?
        raise CostLimitExceeded, "Monthly AI cost limit exceeded: $#{(monthly_cost_used / 100.0).round(2)} / $#{(MONTHLY_COST_LIMIT_CENTS / 100.0).round(2)}"
      end

      unless allow_today?
        Rails.logger.warn("AI daily soft limit reached. Consider spreading requests.")
      end

      true
    end

    # Track a completed AI request
    # @param input_tokens [Integer] Number of input tokens used
    # @param output_tokens [Integer] Number of output tokens used
    # @param cost_cents [Integer, nil] Actual cost if known, otherwise estimated
    # @param editorialisation [Editorialisation, nil] The editorialisation record to update
    def track!(input_tokens:, output_tokens:, cost_cents: nil, editorialisation: nil)
      cost = cost_cents || estimate_cost(input_tokens: input_tokens, output_tokens: output_tokens)

      if editorialisation
        editorialisation.update!(
          input_tokens: input_tokens,
          output_tokens: output_tokens,
          estimated_cost_cents: cost
        )
      end

      # Log for monitoring
      Rails.logger.info(
        "AiUsageTracker: Tracked #{input_tokens + output_tokens} tokens, " \
        "cost: #{cost} cents, editorialisation_id: #{editorialisation&.id}"
      )

      true
    end

    # Estimate cost in cents for given token counts
    def estimate_cost(input_tokens:, output_tokens:)
      input_cost = (input_tokens / 1000.0) * INPUT_COST_PER_1K
      output_cost = (output_tokens / 1000.0) * OUTPUT_COST_PER_1K
      (input_cost + output_cost).ceil
    end

    # Monthly cost stats
    def monthly_cost_used
      sum_cost(start_of_month)
    end

    def monthly_cost_remaining
      [MONTHLY_COST_LIMIT_CENTS - monthly_cost_used, 0].max
    end

    # Daily cost stats
    def daily_cost_used
      sum_cost(Time.current.beginning_of_day)
    end

    def daily_cost_remaining
      [DAILY_COST_SOFT_LIMIT_CENTS - daily_cost_used, 0].max
    end

    # Monthly token stats
    def monthly_tokens_used
      sum_tokens(start_of_month)
    end

    def monthly_tokens_remaining
      [MONTHLY_TOKEN_LIMIT - monthly_tokens_used, 0].max
    end

    # Daily token stats
    def daily_tokens_used
      sum_tokens(Time.current.beginning_of_day)
    end

    def daily_tokens_remaining
      [DAILY_TOKEN_SOFT_LIMIT - daily_tokens_used, 0].max
    end

    # Get full usage stats for monitoring/display
    # @param tenant [Tenant, nil] Optional tenant to scope stats to
    def usage_stats(tenant: nil)
      {
        cost: cost_stats(tenant: tenant),
        tokens: token_stats(tenant: tenant),
        requests: request_stats(tenant: tenant),
        projections: projections(tenant: tenant),
        models: model_breakdown(tenant: tenant),
        limits: {
          monthly_cost_cents: MONTHLY_COST_LIMIT_CENTS,
          daily_cost_cents: DAILY_COST_SOFT_LIMIT_CENTS,
          monthly_tokens: MONTHLY_TOKEN_LIMIT,
          daily_tokens: DAILY_TOKEN_SOFT_LIMIT
        }
      }
    end

    private

    def start_of_month
      Time.current.beginning_of_month
    end

    def base_scope(tenant: nil)
      scope = Editorialisation.completed

      if tenant
        scope = scope.joins(:site).where(sites: { tenant_id: tenant.id })
      end

      scope
    end

    def sum_cost(since, tenant: nil)
      base_scope(tenant: tenant)
        .where("editorialisations.created_at >= ?", since)
        .sum(:estimated_cost_cents) || 0
    end

    def sum_tokens(since, tenant: nil)
      scope = base_scope(tenant: tenant).where("editorialisations.created_at >= ?", since)
      input = scope.sum(:input_tokens) || 0
      output = scope.sum(:output_tokens) || 0
      # Fallback to tokens_used if new columns not populated
      legacy = scope.where(input_tokens: nil).sum(:tokens_used) || 0
      input + output + legacy
    end

    def cost_stats(tenant: nil)
      monthly_used = tenant ? sum_cost(start_of_month, tenant: tenant) : monthly_cost_used
      daily_used = tenant ? sum_cost(Time.current.beginning_of_day, tenant: tenant) : daily_cost_used

      {
        monthly: {
          used_cents: monthly_used,
          used_dollars: (monthly_used / 100.0).round(2),
          limit_cents: MONTHLY_COST_LIMIT_CENTS,
          limit_dollars: (MONTHLY_COST_LIMIT_CENTS / 100.0).round(2),
          remaining_cents: [MONTHLY_COST_LIMIT_CENTS - monthly_used, 0].max,
          percent_used: ((monthly_used.to_f / MONTHLY_COST_LIMIT_CENTS) * 100).round(1)
        },
        daily: {
          used_cents: daily_used,
          used_dollars: (daily_used / 100.0).round(2),
          soft_limit_cents: DAILY_COST_SOFT_LIMIT_CENTS,
          remaining_cents: [DAILY_COST_SOFT_LIMIT_CENTS - daily_used, 0].max
        }
      }
    end

    def token_stats(tenant: nil)
      monthly_used = tenant ? sum_tokens(start_of_month, tenant: tenant) : monthly_tokens_used
      daily_used = tenant ? sum_tokens(Time.current.beginning_of_day, tenant: tenant) : daily_tokens_used

      scope = base_scope(tenant: tenant).where("editorialisations.created_at >= ?", start_of_month)
      input_total = scope.sum(:input_tokens) || 0
      output_total = scope.sum(:output_tokens) || 0

      {
        monthly: {
          used: monthly_used,
          limit: MONTHLY_TOKEN_LIMIT,
          remaining: [MONTHLY_TOKEN_LIMIT - monthly_used, 0].max,
          percent_used: ((monthly_used.to_f / MONTHLY_TOKEN_LIMIT) * 100).round(1),
          input: input_total,
          output: output_total
        },
        daily: {
          used: daily_used,
          soft_limit: DAILY_TOKEN_SOFT_LIMIT,
          remaining: [DAILY_TOKEN_SOFT_LIMIT - daily_used, 0].max
        }
      }
    end

    def request_stats(tenant: nil)
      scope = base_scope(tenant: tenant)

      {
        total_today: scope.where("editorialisations.created_at >= ?", Time.current.beginning_of_day).count,
        total_this_month: scope.where("editorialisations.created_at >= ?", start_of_month).count,
        avg_tokens_per_request: scope.where("editorialisations.created_at >= ?", start_of_month)
                                     .average(:tokens_used)&.round || 0,
        avg_cost_cents_per_request: scope.where("editorialisations.created_at >= ?", start_of_month)
                                         .average(:estimated_cost_cents)&.round || 0
      }
    end

    def projections(tenant: nil)
      days_elapsed = (Time.current.to_date - Time.current.beginning_of_month.to_date).to_i + 1
      days_in_month = Time.current.end_of_month.day
      days_remaining = days_in_month - days_elapsed + 1

      monthly_cost = tenant ? sum_cost(start_of_month, tenant: tenant) : monthly_cost_used
      daily_average = days_elapsed > 0 ? monthly_cost.to_f / days_elapsed : 0
      projected_total = (daily_average * days_in_month).round

      {
        days_remaining_in_month: days_remaining,
        daily_average_cents: daily_average.round,
        projected_monthly_cents: projected_total,
        projected_monthly_dollars: (projected_total / 100.0).round(2),
        on_track: projected_total <= MONTHLY_COST_LIMIT_CENTS,
        overage_risk: projected_total > MONTHLY_COST_LIMIT_CENTS * 0.9
      }
    end

    def model_breakdown(tenant: nil)
      scope = base_scope(tenant: tenant).where("editorialisations.created_at >= ?", start_of_month)

      scope.group(:ai_model)
           .select(
             "ai_model",
             "COUNT(*) as count",
             "SUM(tokens_used) as total_tokens",
             "SUM(estimated_cost_cents) as total_cost_cents"
           )
           .map do |row|
             {
               model: row.ai_model || "unknown",
               count: row.count,
               total_tokens: row.total_tokens || 0,
               total_cost_cents: row.total_cost_cents || 0,
               total_cost_dollars: ((row.total_cost_cents || 0) / 100.0).round(2)
             }
           end
    end
  end
end
