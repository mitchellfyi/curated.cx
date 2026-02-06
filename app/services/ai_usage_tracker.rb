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
  CostLimitExceeded = RateLimitExceeded # Alias for backward compatibility

  # Cost-based limits (in cents)
  MONTHLY_COST_LIMIT_CENTS = ENV.fetch("AI_MONTHLY_COST_LIMIT_CENTS", 10_000).to_i
  DAILY_COST_SOFT_LIMIT_CENTS = ENV.fetch("AI_DAILY_COST_LIMIT_CENTS", (MONTHLY_COST_LIMIT_CENTS / 31.0).ceil).to_i

  class << self
    # Track a completed AI request
    # Accepts both old (tokens_in/tokens_out) and new (input_tokens/output_tokens) parameter names
    def track!(input_tokens: nil, output_tokens: nil, tokens_in: nil, tokens_out: nil,
               model: "default", editorialisation: nil, tenant: nil, cost_cents: nil)
      # Support both parameter naming conventions
      actual_input = input_tokens || tokens_in || 0
      actual_output = output_tokens || tokens_out || 0

      calculated_cost = cost_cents || calculate_cost(actual_input, actual_output, model)

      if editorialisation
        editorialisation.update!(
          input_tokens: actual_input,
          output_tokens: actual_output,
          estimated_cost_cents: calculated_cost
        )
      end

      Rails.logger.info(
        "[AiUsageTracker] Tracked: in=#{actual_input} out=#{actual_output} " \
        "model=#{model} cost=#{calculated_cost}¢ tenant=#{tenant&.id || 'global'}"
      )

      { input_tokens: actual_input, output_tokens: actual_output, cost_cents: calculated_cost }
    end

    # Check if we're within limits (cost-based)
    def allow?
      monthly_cost_used <= MONTHLY_COST_LIMIT_CENTS
    end

    def allow_today?
      daily_cost_used <= DAILY_COST_SOFT_LIMIT_CENTS
    end

    def can_make_request?
      allow? && allow_today?
    end

    # Raise if over limit
    def check!
      unless allow?
        raise CostLimitExceeded, "Monthly AI cost limit exceeded: #{monthly_cost_used}¢/#{MONTHLY_COST_LIMIT_CENTS}¢"
      end

      unless allow_today?
        Rails.logger.warn("AI daily soft limit reached: #{daily_cost_used}¢/#{DAILY_COST_SOFT_LIMIT_CENTS}¢")
      end

      true
    end

    # Estimate cost in cents for a given number of tokens
    def estimate_cost(input_tokens:, output_tokens:, model: "default")
      calculate_cost(input_tokens, output_tokens, model)
    end

    # Monthly cost used in cents
    def monthly_cost_used(tenant = nil)
      monthly_cost(tenant)
    end

    # Daily cost used in cents
    def daily_cost_used(tenant = nil)
      daily_cost(tenant)
    end

    # Usage stats (global or per-tenant)
    def usage_stats(tenant: nil)
      monthly_tokens = monthly_used(tenant)
      daily_tokens = daily_used(tenant)
      monthly_cost_cents = monthly_cost(tenant)
      daily_cost_cents = daily_cost(tenant)
      monthly_input = monthly_input_tokens(tenant)
      monthly_output = monthly_output_tokens(tenant)
      total_requests = editorialisation_scope(tenant).where("created_at >= ?", start_of_month).count
      today_requests = editorialisation_scope(tenant).where("created_at >= ?", Time.current.beginning_of_day).count

      {
        monthly: {
          used: monthly_tokens,
          limit: MONTHLY_TOKEN_LIMIT,
          remaining: monthly_remaining(tenant),
          percent_used: ((monthly_tokens.to_f / MONTHLY_TOKEN_LIMIT) * 100).round(1)
        },
        daily: {
          used: daily_tokens,
          soft_limit: DAILY_SOFT_LIMIT,
          remaining: daily_remaining(tenant)
        },
        tokens: {
          monthly: {
            used: monthly_tokens,
            limit: MONTHLY_TOKEN_LIMIT,
            percent_used: ((monthly_tokens.to_f / MONTHLY_TOKEN_LIMIT) * 100).round(1),
            input: monthly_input,
            output: monthly_output
          },
          daily: {
            used: daily_tokens
          }
        },
        costs: {
          monthly_cents: monthly_cost_cents,
          daily_cents: daily_cost_cents,
          monthly_dollars: (monthly_cost_cents / 100.0).round(2)
        },
        cost: {
          monthly: {
            used_cents: monthly_cost_cents,
            limit_cents: MONTHLY_COST_LIMIT_CENTS,
            percent_used: MONTHLY_COST_LIMIT_CENTS.positive? ? ((monthly_cost_cents.to_f / MONTHLY_COST_LIMIT_CENTS) * 100).round(1) : 0,
            used_dollars: (monthly_cost_cents / 100.0).round(2),
            limit_dollars: (MONTHLY_COST_LIMIT_CENTS / 100.0).round(2)
          },
          daily: {
            used_cents: daily_cost_cents,
            soft_limit_cents: DAILY_COST_SOFT_LIMIT_CENTS,
            used_dollars: (daily_cost_cents / 100.0).round(2)
          }
        },
        projections: {
          days_remaining_in_month: days_remaining_in_month,
          projected_monthly_tokens: projected_monthly_usage(tenant),
          projected_monthly_cost_cents: projected_monthly_cost(tenant),
          projected_monthly_dollars: (projected_monthly_cost(tenant) / 100.0).round(2),
          on_track: projected_monthly_cost(tenant) <= MONTHLY_COST_LIMIT_CENTS
        },
        breakdown: usage_breakdown(tenant),
        models: model_breakdown(tenant),
        requests: {
          total_this_month: total_requests,
          total_today: today_requests,
          avg_tokens_per_request: total_requests.positive? ? (monthly_tokens.to_f / total_requests).round : 0,
          avg_cost_cents_per_request: total_requests.positive? ? (monthly_cost_cents.to_f / total_requests).round(2) : 0
        }
      }
    end

    def model_breakdown(tenant = nil)
      scope = editorialisation_scope(tenant).where("created_at >= ?", start_of_month)

      scope.group(:ai_model).select(
        "ai_model as model",
        "COUNT(*) as count",
        "COALESCE(SUM(input_tokens), 0) + COALESCE(SUM(output_tokens), 0) as total_tokens",
        "COALESCE(SUM(estimated_cost_cents), 0) as total_cost_cents"
      ).map do |row|
        {
          model: row.model,
          count: row.count,
          total_tokens: row.total_tokens,
          total_cost_dollars: (row.total_cost_cents.to_f / 100).round(2)
        }
      end
    end

    # Token usage methods
    def monthly_used(tenant = nil)
      scope = editorialisation_scope(tenant).where("created_at >= ?", start_of_month)
      (scope.sum(:input_tokens) || 0) + (scope.sum(:output_tokens) || 0)
    end

    def monthly_input_tokens(tenant = nil)
      editorialisation_scope(tenant).where("created_at >= ?", start_of_month).sum(:input_tokens) || 0
    end

    def monthly_output_tokens(tenant = nil)
      editorialisation_scope(tenant).where("created_at >= ?", start_of_month).sum(:output_tokens) || 0
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
