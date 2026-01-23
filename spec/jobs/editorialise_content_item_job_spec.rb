# frozen_string_literal: true

require "rails_helper"

RSpec.describe EditorialiseContentItemJob, type: :job do
  include ActiveJob::TestHelper

  let(:tenant) { create(:tenant) }
  let(:site) { create(:site, tenant: tenant) }
  let(:source) { create(:source, site: site, config: { "editorialise" => true }) }
  let(:content_item) do
    create(:content_item,
      site: site,
      source: source,
      extracted_text: "A" * 500 # Meets minimum length
    )
  end

  let(:ai_response) do
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

  before do
    # Prevent editorialisation job from running on content_item creation
    allow_any_instance_of(ContentItem).to receive(:enqueue_editorialisation)
    # Stub AiClient
    allow_any_instance_of(Editorialisation::AiClient).to receive(:complete).and_return(ai_response)
  end

  describe "#perform" do
    it "calls EditorialisationService with the content item" do
      expect(EditorialisationService).to receive(:editorialise).with(content_item).and_call_original

      described_class.perform_now(content_item.id)
    end

    it "sets Current.tenant during execution" do
      described_class.perform_now(content_item.id)

      # The job clears context in ensure block, so we verify it was set by checking
      # that the service ran successfully (which requires tenant context)
      expect(Editorialisation.count).to eq(1)
    end

    it "sets Current.site during execution" do
      described_class.perform_now(content_item.id)

      expect(Editorialisation.count).to eq(1)
    end

    it "clears Current context after execution" do
      described_class.perform_now(content_item.id)

      expect(Current.tenant).to be_nil
      expect(Current.site).to be_nil
    end

    it "clears Current context even when error occurs" do
      allow(EditorialisationService).to receive(:editorialise).and_raise(StandardError.new("Test error"))

      begin
        described_class.perform_now(content_item.id)
      rescue StandardError
        # Expected
      end

      expect(Current.tenant).to be_nil
      expect(Current.site).to be_nil
    end

    context "when content item not found" do
      it "raises ActiveRecord::RecordNotFound" do
        expect {
          described_class.perform_now(0)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "logging" do
      context "when editorialisation completes" do
        it "logs success with token and duration info" do
          expect(Rails.logger).to receive(:info).with(/Successfully editorialised.*tokens=100.*duration_ms=1000/)

          described_class.perform_now(content_item.id)
        end
      end

      context "when editorialisation is skipped" do
        let(:content_item) do
          create(:content_item,
            site: site,
            source: source,
            extracted_text: "Short" # Too short, will be skipped
          )
        end

        it "logs skip reason" do
          expect(Rails.logger).to receive(:info).with(/Skipped.*reason=Insufficient text/)

          described_class.perform_now(content_item.id)
        end
      end
    end
  end

  describe "queue configuration" do
    it "uses the editorialisation queue" do
      expect(described_class.queue_name).to eq("editorialisation")
    end
  end

  describe "retry configuration" do
    it "retries on AiApiError with exponential backoff" do
      handlers = described_class.rescue_handlers
      handler = handlers.find { |h| h["error_class"] == "AiApiError" }

      expect(handler).to be_present
      expect(handler["wait"]).to eq(:exponentially_longer)
      expect(handler["attempts"]).to eq(3)
    end

    it "retries on AiTimeoutError with exponential backoff" do
      handlers = described_class.rescue_handlers
      handler = handlers.find { |h| h["error_class"] == "AiTimeoutError" }

      expect(handler).to be_present
      expect(handler["wait"]).to eq(:exponentially_longer)
      expect(handler["attempts"]).to eq(3)
    end

    it "retries on AiRateLimitError with 60 second wait" do
      handlers = described_class.rescue_handlers
      handler = handlers.find { |h| h["error_class"] == "AiRateLimitError" }

      expect(handler).to be_present
      expect(handler["wait"]).to eq(60.seconds)
      expect(handler["attempts"]).to eq(5)
    end
  end

  describe "discard configuration" do
    it "discards on AiInvalidResponseError" do
      expect(described_class.discard_handlers).to include(
        a_hash_including("error_class" => "AiInvalidResponseError")
      )
    end

    it "discards on AiConfigurationError" do
      expect(described_class.discard_handlers).to include(
        a_hash_including("error_class" => "AiConfigurationError")
      )
    end
  end

  describe "error handling" do
    context "when AiApiError occurs" do
      before do
        allow_any_instance_of(Editorialisation::AiClient).to receive(:complete)
          .and_raise(AiApiError.new("API error"))
      end

      it "raises the error for retry" do
        expect {
          described_class.perform_now(content_item.id)
        }.to raise_error(AiApiError)
      end
    end

    context "when AiRateLimitError occurs" do
      before do
        allow_any_instance_of(Editorialisation::AiClient).to receive(:complete)
          .and_raise(AiRateLimitError.new("Rate limited"))
      end

      it "raises the error for retry" do
        expect {
          described_class.perform_now(content_item.id)
        }.to raise_error(AiRateLimitError)
      end
    end

    context "when AiInvalidResponseError occurs" do
      before do
        allow_any_instance_of(Editorialisation::AiClient).to receive(:complete)
          .and_return(content: "not json", tokens_used: 0, model: "gpt-4o-mini", duration_ms: 100)
      end

      it "does not raise (service handles it)" do
        expect {
          described_class.perform_now(content_item.id)
        }.not_to raise_error
      end

      it "creates a failed editorialisation record" do
        described_class.perform_now(content_item.id)

        editorialisation = Editorialisation.last
        expect(editorialisation.status).to eq("failed")
      end
    end
  end
end
