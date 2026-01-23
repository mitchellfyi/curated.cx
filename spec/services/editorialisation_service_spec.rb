# frozen_string_literal: true

require "rails_helper"

RSpec.describe EditorialisationService, type: :service do
  let(:tenant) { create(:tenant) }
  let(:site) { create(:site, tenant: tenant) }
  let(:source) { create(:source, site: site, config: { "editorialise" => true }) }
  let(:content_item) do
    create(:content_item,
      site: site,
      source: source,
      extracted_text: "A" * 500, # Meets minimum length
      title: "Test Article",
      url_canonical: "https://example.com/article",
      description: "Test description"
    )
  end

  let(:ai_response) do
    {
      content: {
        "summary" => "This is a test summary of the article.",
        "why_it_matters" => "This matters because it demonstrates important concepts.",
        "suggested_tags" => [ "technology", "innovation" ]
      }.to_json,
      tokens_used: 150,
      model: "gpt-4o-mini",
      duration_ms: 1500
    }
  end

  before do
    # Stub AiClient to avoid real API calls
    allow_any_instance_of(EditorialisationServices::AiClient).to receive(:complete).and_return(ai_response)
    # Prevent editorialisation job from running on content_item creation
    allow_any_instance_of(ContentItem).to receive(:enqueue_editorialisation)
  end

  describe ".editorialise" do
    it "delegates to instance call" do
      expect_any_instance_of(described_class).to receive(:call)
      described_class.editorialise(content_item)
    end
  end

  describe "#call" do
    context "happy path" do
      it "creates an Editorialisation record" do
        expect {
          described_class.editorialise(content_item)
        }.to change(Editorialisation, :count).by(1)
      end

      it "marks the editorialisation as completed" do
        result = described_class.editorialise(content_item)

        expect(result.status).to eq("completed")
      end

      it "stores the AI response" do
        result = described_class.editorialise(content_item)

        expect(result.parsed_response["summary"]).to eq("This is a test summary of the article.")
        expect(result.parsed_response["why_it_matters"]).to eq("This matters because it demonstrates important concepts.")
        expect(result.parsed_response["suggested_tags"]).to eq([ "technology", "innovation" ])
      end

      it "stores token usage and duration" do
        result = described_class.editorialise(content_item)

        expect(result.tokens_used).to eq(150)
        expect(result.duration_ms).to eq(1500)
        expect(result.ai_model).to eq("gpt-4o-mini")
      end

      it "stores the prompt version" do
        result = described_class.editorialise(content_item)

        expect(result.prompt_version).to eq("v1.0.0")
      end

      it "stores the prompt text" do
        result = described_class.editorialise(content_item)

        expect(result.prompt_text).to include("Test Article")
      end

      it "updates the content item with AI results" do
        described_class.editorialise(content_item)
        content_item.reload

        expect(content_item.ai_summary).to eq("This is a test summary of the article.")
        expect(content_item.why_it_matters).to eq("This matters because it demonstrates important concepts.")
        expect(content_item.ai_suggested_tags).to eq([ "technology", "innovation" ])
        expect(content_item.editorialised_at).to be_present
      end
    end

    context "eligibility: text too short" do
      let(:content_item) do
        create(:content_item,
          site: site,
          source: source,
          extracted_text: "Short text" # Only 10 chars, minimum is 200
        )
      end

      it "creates a skipped Editorialisation record" do
        result = described_class.editorialise(content_item)

        expect(result.status).to eq("skipped")
        expect(result.error_message).to include("Insufficient text")
        expect(result.error_message).to include("10 chars")
        expect(result.error_message).to include("minimum 200")
      end

      it "does not call the AI API" do
        expect_any_instance_of(EditorialisationServices::AiClient).not_to receive(:complete)
        described_class.editorialise(content_item)
      end

      it "does not update the content item" do
        described_class.editorialise(content_item)
        content_item.reload

        expect(content_item.editorialised_at).to be_nil
      end
    end

    context "eligibility: already editorialised" do
      before do
        content_item.update_columns(editorialised_at: 1.hour.ago)
      end

      it "creates a skipped record" do
        result = described_class.editorialise(content_item)

        expect(result.status).to eq("skipped")
        expect(result.error_message).to eq("Already editorialised")
      end
    end

    context "eligibility: existing completed editorialisation" do
      let!(:existing_editorialisation) do
        create(:editorialisation, :completed, content_item: content_item)
      end

      it "returns the existing editorialisation" do
        result = described_class.editorialise(content_item)

        # Returns the existing record rather than creating a duplicate
        expect(result.id).to eq(existing_editorialisation.id)
        expect(result.status).to eq("completed")
      end
    end

    context "eligibility: source editorialisation disabled" do
      let(:source) { create(:source, site: site, config: { "editorialise" => false }) }

      it "creates a skipped record" do
        result = described_class.editorialise(content_item)

        expect(result.status).to eq("skipped")
        expect(result.error_message).to eq("Source editorialisation disabled")
      end
    end

    context "eligibility: source with no editorialise config" do
      let(:source) { create(:source, site: site, config: {}) }

      it "creates a skipped record" do
        result = described_class.editorialise(content_item)

        expect(result.status).to eq("skipped")
        expect(result.error_message).to eq("Source editorialisation disabled")
      end
    end

    context "eligibility: nil extracted_text" do
      let(:content_item) do
        create(:content_item,
          site: site,
          source: source,
          extracted_text: nil
        )
      end

      it "creates a skipped record for insufficient text" do
        result = described_class.editorialise(content_item)

        expect(result.status).to eq("skipped")
        expect(result.error_message).to include("Insufficient text")
        expect(result.error_message).to include("0 chars")
      end
    end

    context "output length enforcement" do
      let(:long_summary) { "A" * 500 }
      let(:long_why_it_matters) { "B" * 1000 }
      let(:many_tags) { (1..10).map { |i| "tag#{i}" } }

      let(:ai_response) do
        {
          content: {
            "summary" => long_summary,
            "why_it_matters" => long_why_it_matters,
            "suggested_tags" => many_tags
          }.to_json,
          tokens_used: 150,
          model: "gpt-4o-mini",
          duration_ms: 1500
        }
      end

      it "truncates summary to 280 characters" do
        result = described_class.editorialise(content_item)

        expect(result.parsed_response["summary"].length).to be <= 280
      end

      it "truncates why_it_matters to 500 characters" do
        result = described_class.editorialise(content_item)

        expect(result.parsed_response["why_it_matters"].length).to be <= 500
      end

      it "limits suggested_tags to 5 items" do
        result = described_class.editorialise(content_item)

        expect(result.parsed_response["suggested_tags"].length).to eq(5)
      end
    end

    context "AI API errors (retryable)" do
      before do
        allow_any_instance_of(EditorialisationServices::AiClient).to receive(:complete)
          .and_raise(AiApiError.new("API request failed"))
      end

      it "marks the editorialisation as failed" do
        expect {
          described_class.editorialise(content_item)
        }.to raise_error(AiApiError)

        editorialisation = Editorialisation.last
        expect(editorialisation.status).to eq("failed")
        expect(editorialisation.error_message).to eq("API request failed")
      end
    end

    context "AI rate limit errors (retryable)" do
      before do
        allow_any_instance_of(EditorialisationServices::AiClient).to receive(:complete)
          .and_raise(AiRateLimitError.new("Rate limit exceeded"))
      end

      it "marks the editorialisation as failed and re-raises" do
        expect {
          described_class.editorialise(content_item)
        }.to raise_error(AiRateLimitError)

        editorialisation = Editorialisation.last
        expect(editorialisation.status).to eq("failed")
      end
    end

    context "AI timeout errors (retryable)" do
      before do
        allow_any_instance_of(EditorialisationServices::AiClient).to receive(:complete)
          .and_raise(AiTimeoutError.new("Request timed out"))
      end

      it "marks the editorialisation as failed and re-raises" do
        expect {
          described_class.editorialise(content_item)
        }.to raise_error(AiTimeoutError)

        editorialisation = Editorialisation.last
        expect(editorialisation.status).to eq("failed")
      end
    end

    context "AI invalid response error (non-retryable)" do
      before do
        allow_any_instance_of(EditorialisationServices::AiClient).to receive(:complete)
          .and_return(content: "not valid json", tokens_used: 0, model: "gpt-4o-mini", duration_ms: 100)
      end

      it "marks the editorialisation as failed but does not re-raise" do
        result = described_class.editorialise(content_item)

        expect(result.status).to eq("failed")
        expect(result.error_message).to include("Failed to parse AI response")
      end
    end

    context "AI response missing required fields" do
      before do
        allow_any_instance_of(EditorialisationServices::AiClient).to receive(:complete)
          .and_return(content: '{"foo": "bar"}', tokens_used: 0, model: "gpt-4o-mini", duration_ms: 100)
      end

      it "marks the editorialisation as failed" do
        result = described_class.editorialise(content_item)

        expect(result.status).to eq("failed")
        expect(result.error_message).to include("missing required fields")
      end
    end

    context "AI configuration error (non-retryable)" do
      before do
        allow_any_instance_of(EditorialisationServices::AiClient).to receive(:complete)
          .and_raise(AiConfigurationError.new("API key not configured"))
      end

      it "marks the editorialisation as failed but does not re-raise" do
        result = described_class.editorialise(content_item)

        expect(result.status).to eq("failed")
        expect(result.error_message).to eq("API key not configured")
      end
    end

    context "unexpected error" do
      before do
        allow_any_instance_of(EditorialisationServices::AiClient).to receive(:complete)
          .and_raise(StandardError.new("Something went wrong"))
      end

      it "marks the editorialisation as failed and re-raises" do
        expect {
          described_class.editorialise(content_item)
        }.to raise_error(StandardError, "Something went wrong")

        editorialisation = Editorialisation.last
        expect(editorialisation.status).to eq("failed")
        expect(editorialisation.error_message).to eq("Unexpected error: Something went wrong")
      end
    end
  end

  describe "MIN_TEXT_LENGTH constant" do
    it "is set to 200" do
      expect(described_class::MIN_TEXT_LENGTH).to eq(200)
    end
  end
end
