# frozen_string_literal: true

# Helpers for stubbing AI client in tests.
# The AiClient requires an API key, which is not available in CI.
# This module provides helpers to stub the client for testing.

module AiClientHelpers
  # Default mock AI response for editorialisation
  def default_ai_response
    {
      content: {
        "summary" => "Test summary",
        "why_it_matters" => "Test context",
        "suggested_tags" => [ "tag1" ]
      }.to_json,
      tokens_used: 100,
      model: "gpt-4o-mini",
      duration_ms: 1000
    }
  end

  # Stub the AI client to return a successful response
  def stub_ai_client(response: nil)
    response ||= default_ai_response
    # Stub the API key validation first
    allow_any_instance_of(EditorialisationServices::AiClient).to receive(:validate_api_key!)
    # Then stub the complete method
    allow_any_instance_of(EditorialisationServices::AiClient).to receive(:complete).and_return(response)
  end

  # Stub the AI client to raise an error
  def stub_ai_client_error(error)
    allow_any_instance_of(EditorialisationServices::AiClient).to receive(:validate_api_key!)
    allow_any_instance_of(EditorialisationServices::AiClient).to receive(:complete).and_raise(error)
  end

  # Stub the AI client to return invalid JSON
  def stub_ai_client_invalid_json
    allow_any_instance_of(EditorialisationServices::AiClient).to receive(:validate_api_key!)
    allow_any_instance_of(EditorialisationServices::AiClient).to receive(:complete)
      .and_return(content: "not valid json", tokens_used: 0, model: "gpt-4o-mini", duration_ms: 100)
  end
end

RSpec.configure do |config|
  config.include AiClientHelpers
end
