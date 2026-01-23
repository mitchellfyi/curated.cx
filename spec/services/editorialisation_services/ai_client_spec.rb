# frozen_string_literal: true

require "rails_helper"

RSpec.describe EditorialisationServices::AiClient, type: :service do
  let(:api_key) { "test-api-key-12345" }
  let(:system_prompt) { "You are a helpful assistant." }
  let(:user_prompt) { "Summarize this article." }

  before do
    # Set up credentials for testing
    allow(Rails.application.credentials).to receive(:dig).with(:openai, :api_key).and_return(api_key)
  end

  describe "#initialize" do
    it "uses provided API key" do
      client = described_class.new(api_key: "custom-key")
      expect(client.instance_variable_get(:@api_key)).to eq("custom-key")
    end

    it "falls back to credentials API key" do
      client = described_class.new
      expect(client.instance_variable_get(:@api_key)).to eq(api_key)
    end

    it "falls back to environment variable" do
      allow(Rails.application.credentials).to receive(:dig).with(:openai, :api_key).and_return(nil)
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return("env-api-key")

      client = described_class.new
      expect(client.instance_variable_get(:@api_key)).to eq("env-api-key")
    end

    it "raises AiConfigurationError if no API key available" do
      allow(Rails.application.credentials).to receive(:dig).with(:openai, :api_key).and_return(nil)
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return(nil)

      expect {
        described_class.new
      }.to raise_error(AiConfigurationError, /API key not configured/)
    end
  end

  describe "#complete" do
    let(:client) { described_class.new(api_key: api_key) }

    let(:successful_response) do
      {
        "id" => "chatcmpl-123",
        "object" => "chat.completion",
        "created" => 1677652288,
        "model" => "gpt-4o-mini",
        "choices" => [
          {
            "index" => 0,
            "message" => {
              "role" => "assistant",
              "content" => '{"summary": "Test summary", "why_it_matters": "Test context"}'
            },
            "finish_reason" => "stop"
          }
        ],
        "usage" => {
          "prompt_tokens" => 50,
          "completion_tokens" => 100,
          "total_tokens" => 150
        }
      }
    end

    before do
      stub_request(:post, "https://api.openai.com/v1/chat/completions")
        .to_return(
          status: 200,
          body: successful_response.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "makes a request to OpenAI API" do
      client.complete(system_prompt: system_prompt, user_prompt: user_prompt)

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
    end

    it "sends correct message structure" do
      client.complete(system_prompt: system_prompt, user_prompt: user_prompt)

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with(body: hash_including(
          "messages" => [
            { "role" => "system", "content" => system_prompt },
            { "role" => "user", "content" => user_prompt }
          ]
        ))
    end

    it "uses default model if not specified" do
      client.complete(system_prompt: system_prompt, user_prompt: user_prompt)

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with(body: hash_including("model" => "gpt-4o-mini"))
    end

    it "uses specified model" do
      client.complete(
        system_prompt: system_prompt,
        user_prompt: user_prompt,
        model: "gpt-4-turbo"
      )

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with(body: hash_including("model" => "gpt-4-turbo"))
    end

    it "uses specified max_tokens" do
      client.complete(
        system_prompt: system_prompt,
        user_prompt: user_prompt,
        max_tokens: 1000
      )

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with(body: hash_including("max_tokens" => 1000))
    end

    it "uses specified temperature" do
      client.complete(
        system_prompt: system_prompt,
        user_prompt: user_prompt,
        temperature: 0.7
      )

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with(body: hash_including("temperature" => 0.7))
    end

    it "requests JSON response format" do
      client.complete(system_prompt: system_prompt, user_prompt: user_prompt)

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with(body: hash_including("response_format" => { "type" => "json_object" }))
    end

    it "returns structured response" do
      result = client.complete(system_prompt: system_prompt, user_prompt: user_prompt)

      expect(result).to be_a(Hash)
      expect(result[:content]).to eq('{"summary": "Test summary", "why_it_matters": "Test context"}')
      expect(result[:tokens_used]).to eq(150)
      expect(result[:model]).to eq("gpt-4o-mini")
      expect(result[:duration_ms]).to be_a(Integer)
    end

    context "when response content is empty" do
      let(:empty_response) do
        {
          "choices" => [
            {
              "message" => {
                "content" => ""
              }
            }
          ]
        }
      end

      before do
        stub_request(:post, "https://api.openai.com/v1/chat/completions")
          .to_return(
            status: 200,
            body: empty_response.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "raises AiInvalidResponseError" do
        expect {
          client.complete(system_prompt: system_prompt, user_prompt: user_prompt)
        }.to raise_error(AiInvalidResponseError, /Empty response/)
      end
    end

    context "when rate limited (429)" do
      before do
        stub_request(:post, "https://api.openai.com/v1/chat/completions")
          .to_return(status: 429, body: "Rate limit exceeded")
      end

      it "raises AiRateLimitError" do
        expect {
          client.complete(system_prompt: system_prompt, user_prompt: user_prompt)
        }.to raise_error(AiRateLimitError)
      end
    end

    context "when server error (500)" do
      before do
        stub_request(:post, "https://api.openai.com/v1/chat/completions")
          .to_return(status: 500, body: "Internal Server Error")
      end

      it "raises AiApiError" do
        expect {
          client.complete(system_prompt: system_prompt, user_prompt: user_prompt)
        }.to raise_error(AiApiError)
      end
    end

    context "when request times out" do
      before do
        stub_request(:post, "https://api.openai.com/v1/chat/completions")
          .to_timeout
      end

      it "raises AiTimeoutError" do
        expect {
          client.complete(system_prompt: system_prompt, user_prompt: user_prompt)
        }.to raise_error(AiTimeoutError, /timed out/)
      end
    end

    context "when network error occurs" do
      before do
        stub_request(:post, "https://api.openai.com/v1/chat/completions")
          .to_raise(Faraday::ConnectionFailed.new("Connection refused"))
      end

      it "raises AiApiError" do
        expect {
          client.complete(system_prompt: system_prompt, user_prompt: user_prompt)
        }.to raise_error(AiApiError)
      end
    end
  end

  describe "constants" do
    it "has DEFAULT_MODEL set to gpt-4o-mini" do
      expect(described_class::DEFAULT_MODEL).to eq("gpt-4o-mini")
    end

    it "has DEFAULT_MAX_TOKENS set to 800" do
      expect(described_class::DEFAULT_MAX_TOKENS).to eq(800)
    end

    it "has DEFAULT_TEMPERATURE set to 0.3" do
      expect(described_class::DEFAULT_TEMPERATURE).to eq(0.3)
    end

    it "has DEFAULT_TIMEOUT set to 30" do
      expect(described_class::DEFAULT_TIMEOUT).to eq(30)
    end
  end
end
