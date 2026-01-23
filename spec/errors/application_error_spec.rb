# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationError do
  describe "error hierarchy" do
    it "inherits from StandardError" do
      expect(described_class.superclass).to eq(StandardError)
    end

    it "does not inherit from Exception (safe to rescue)" do
      expect(described_class.ancestors).not_to include(SystemExit)
      expect(described_class.ancestors).not_to include(Interrupt)
    end
  end

  describe "#initialize" do
    it "accepts a message" do
      error = described_class.new("Something went wrong")
      expect(error.message).to eq("Something went wrong")
    end

    it "accepts an optional context hash" do
      error = described_class.new("Error", context: { user_id: 123, action: "save" })
      expect(error.context).to eq({ user_id: 123, action: "save" })
    end

    it "defaults context to empty hash" do
      error = described_class.new("Error")
      expect(error.context).to eq({})
    end

    it "works without arguments" do
      error = described_class.new
      expect(error.message).to eq("ApplicationError")
      expect(error.context).to eq({})
    end
  end

  describe "#to_h" do
    it "returns structured error data" do
      error = described_class.new("Failed", context: { listing_id: 456 })

      expect(error.to_h).to eq({
        error_class: "ApplicationError",
        message: "Failed",
        context: { listing_id: 456 }
      })
    end
  end

  describe "can be raised and rescued" do
    it "can be raised" do
      expect { raise described_class, "test error" }.to raise_error(described_class, "test error")
    end

    it "is caught by rescue StandardError" do
      caught = false
      begin
        raise described_class, "test"
      rescue StandardError
        caught = true
      end
      expect(caught).to be true
    end
  end
end

RSpec.describe ExternalServiceError do
  it "inherits from ApplicationError" do
    expect(described_class.superclass).to eq(ApplicationError)
  end

  it "can carry context" do
    error = described_class.new("API timeout", context: { service: "stripe", timeout: 30 })

    expect(error.message).to eq("API timeout")
    expect(error.context[:service]).to eq("stripe")
    expect(error.context[:timeout]).to eq(30)
  end

  it "is retryable (appropriate for transient failures)" do
    # This is a documentation test - ExternalServiceError indicates transient failures
    # that should be retried. ApplicationJob is configured with:
    # retry_on ExternalServiceError, wait: :exponentially_longer, attempts: 3
    expect(ExternalServiceError.new).to be_a(ApplicationError)
  end
end

RSpec.describe ContentExtractionError do
  it "inherits from ApplicationError" do
    expect(described_class.superclass).to eq(ApplicationError)
  end

  it "can carry context about extraction failure" do
    error = described_class.new(
      "Failed to parse HTML",
      context: { url: "https://example.com", content_type: "text/html" }
    )

    expect(error.message).to eq("Failed to parse HTML")
    expect(error.context[:url]).to eq("https://example.com")
  end
end

RSpec.describe ConfigurationError do
  it "inherits from ApplicationError" do
    expect(described_class.superclass).to eq(ApplicationError)
  end

  it "indicates permanent failure (should not retry)" do
    # This is a documentation test - ConfigurationError indicates permanent failures
    # that should not be retried. ApplicationJob is configured with:
    # discard_on ConfigurationError
    expect(ConfigurationError.new).to be_a(ApplicationError)
  end

  it "can carry context about missing configuration" do
    error = described_class.new(
      "API key not configured",
      context: { required_key: "STRIPE_API_KEY" }
    )

    expect(error.message).to eq("API key not configured")
    expect(error.context[:required_key]).to eq("STRIPE_API_KEY")
  end
end

RSpec.describe DnsError do
  it "inherits from ApplicationError" do
    expect(described_class.superclass).to eq(ApplicationError)
  end

  it "can carry context about DNS failure" do
    error = described_class.new(
      "DNS resolution failed",
      context: { hostname: "example.com", error_type: "NXDOMAIN" }
    )

    expect(error.message).to eq("DNS resolution failed")
    expect(error.context[:hostname]).to eq("example.com")
  end
end
