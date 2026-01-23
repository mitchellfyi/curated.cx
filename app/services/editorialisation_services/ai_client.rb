# frozen_string_literal: true

module EditorialisationServices
  # Wrapper around OpenAI client for editorialisation API calls.
  # Handles authentication, error mapping, and response formatting.
  #
  # Usage:
  #   client = Editorialisation::AiClient.new
  #   result = client.complete(
  #     system_prompt: "You are a helpful assistant",
  #     user_prompt: "Summarize this article",
  #     model: "gpt-4o-mini",
  #     max_tokens: 800
  #   )
  #
  class AiClient
    DEFAULT_MODEL = "gpt-4o-mini"
    DEFAULT_MAX_TOKENS = 800
    DEFAULT_TEMPERATURE = 0.3
    DEFAULT_TIMEOUT = 30

    def initialize(api_key: nil)
      @api_key = api_key || fetch_api_key
      validate_api_key!
    end

    # Make a chat completion request
    # Returns: { content: String, tokens_used: Integer, model: String, duration_ms: Integer }
    def complete(system_prompt:, user_prompt:, model: nil, max_tokens: nil, temperature: nil)
      model ||= DEFAULT_MODEL
      max_tokens ||= DEFAULT_MAX_TOKENS
      temperature ||= DEFAULT_TEMPERATURE

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      response = make_request(
        model: model,
        messages: build_messages(system_prompt, user_prompt),
        max_tokens: max_tokens,
        temperature: temperature
      )

      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).to_i

      parse_response(response, model, duration_ms)
    rescue Faraday::TimeoutError, Net::ReadTimeout => e
      raise AiTimeoutError.new("AI API request timed out: #{e.message}")
    rescue Faraday::Error => e
      handle_faraday_error(e)
    rescue OpenAI::Error => e
      handle_openai_error(e)
    end

    private

    def fetch_api_key
      # Try Rails credentials first, then environment variable
      Rails.application.credentials.dig(:openai, :api_key) ||
        ENV["OPENAI_API_KEY"]
    end

    def validate_api_key!
      return if @api_key.present?

      raise AiConfigurationError.new(
        "OpenAI API key not configured. Set OPENAI_API_KEY or add to credentials."
      )
    end

    def client
      @client ||= OpenAI::Client.new(
        access_token: @api_key,
        request_timeout: DEFAULT_TIMEOUT
      )
    end

    def build_messages(system_prompt, user_prompt)
      [
        { role: "system", content: system_prompt },
        { role: "user", content: user_prompt }
      ]
    end

    def make_request(model:, messages:, max_tokens:, temperature:)
      client.chat(
        parameters: {
          model: model,
          messages: messages,
          max_tokens: max_tokens,
          temperature: temperature,
          response_format: { type: "json_object" }
        }
      )
    end

    def parse_response(response, model, duration_ms)
      content = response.dig("choices", 0, "message", "content")
      usage = response["usage"] || {}

      if content.blank?
        raise AiInvalidResponseError.new("Empty response from AI API")
      end

      {
        content: content,
        tokens_used: usage["total_tokens"] || 0,
        model: model,
        duration_ms: duration_ms
      }
    end

    def handle_faraday_error(error)
      message = "AI API request failed: #{error.message}"

      case error
      when Faraday::TooManyRequestsError
        raise AiRateLimitError.new(message)
      when Faraday::ServerError
        raise AiApiError.new(message)
      else
        raise AiApiError.new(message)
      end
    end

    def handle_openai_error(error)
      message = "OpenAI API error: #{error.message}"

      # Check for rate limiting in error message or response
      if error.message.include?("rate limit") || error.message.include?("429")
        raise AiRateLimitError.new(message)
      end

      raise AiApiError.new(message)
    end
  end
end
