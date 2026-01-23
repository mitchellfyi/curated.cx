# frozen_string_literal: true

require "rails_helper"

RSpec.describe EditorialisationServices::PromptManager, type: :service do
  let(:tenant) { create(:tenant) }
  let(:site) { create(:site, tenant: tenant) }
  let(:source) { create(:source, site: site) }
  let(:content_item) do
    build(:content_item,
      site: site,
      source: source,
      title: "Test Article Title",
      url_canonical: "https://example.com/test-article",
      description: "This is a test description",
      extracted_text: "This is the extracted text from the article." * 50
    )
  end

  describe "PROMPTS_PATH" do
    it "points to config/editorialisation/prompts" do
      expect(described_class::PROMPTS_PATH.to_s).to end_with("config/editorialisation/prompts")
    end
  end

  describe "DEFAULT_VERSION" do
    it "is v1.0.0" do
      expect(described_class::DEFAULT_VERSION).to eq("v1.0.0")
    end
  end

  describe "MAX_TEXT_LENGTH" do
    it "is 4000" do
      expect(described_class::MAX_TEXT_LENGTH).to eq(4000)
    end
  end

  describe ".current_version" do
    it "returns the latest version from available prompt files" do
      version = described_class.current_version
      expect(version).to match(/^v\d+\.\d+\.\d+$/)
    end

    it "returns DEFAULT_VERSION if no prompt files exist" do
      allow(Dir).to receive(:glob).and_return([])
      expect(described_class.current_version).to eq("v1.0.0")
    end
  end

  describe ".get_prompt" do
    it "returns prompt configuration for a version" do
      config = described_class.get_prompt("v1.0.0")

      expect(config).to be_a(Hash)
      expect(config["version"]).to eq("v1.0.0")
      expect(config["system_prompt"]).to be_present
      expect(config["user_prompt_template"]).to be_present
    end
  end

  describe "#initialize" do
    it "loads the specified version" do
      manager = described_class.new(version: "v1.0.0")
      expect(manager.version).to eq("v1.0.0")
    end

    it "defaults to current_version if no version specified" do
      manager = described_class.new
      expect(manager.version).to eq(described_class.current_version)
    end

    it "raises PromptNotFoundError for invalid version" do
      expect {
        described_class.new(version: "v99.99.99")
      }.to raise_error(described_class::PromptNotFoundError, /v99.99.99 not found/)
    end
  end

  describe "#current_version" do
    it "delegates to class method" do
      manager = described_class.new
      expect(manager.current_version).to eq(described_class.current_version)
    end
  end

  describe "#config" do
    it "returns the loaded configuration" do
      manager = described_class.new(version: "v1.0.0")

      expect(manager.config).to be_a(Hash)
      expect(manager.config["version"]).to eq("v1.0.0")
    end
  end

  describe "#build_prompt" do
    let(:manager) { described_class.new(version: "v1.0.0") }

    it "returns a hash with required keys" do
      prompt = manager.build_prompt(content_item)

      expect(prompt).to be_a(Hash)
      expect(prompt).to have_key(:system_prompt)
      expect(prompt).to have_key(:user_prompt)
      expect(prompt).to have_key(:version)
      expect(prompt).to have_key(:model)
    end

    it "includes the system prompt" do
      prompt = manager.build_prompt(content_item)

      expect(prompt[:system_prompt]).to be_present
      expect(prompt[:system_prompt]).to include("content curator")
    end

    it "interpolates title in user prompt" do
      prompt = manager.build_prompt(content_item)

      expect(prompt[:user_prompt]).to include("Test Article Title")
    end

    it "interpolates URL in user prompt" do
      prompt = manager.build_prompt(content_item)

      expect(prompt[:user_prompt]).to include("https://example.com/test-article")
    end

    it "interpolates description in user prompt" do
      prompt = manager.build_prompt(content_item)

      expect(prompt[:user_prompt]).to include("This is a test description")
    end

    it "interpolates extracted text in user prompt" do
      prompt = manager.build_prompt(content_item)

      expect(prompt[:user_prompt]).to include("extracted text from the article")
    end

    it "includes the version" do
      prompt = manager.build_prompt(content_item)

      expect(prompt[:version]).to eq("v1.0.0")
    end

    it "includes model configuration" do
      prompt = manager.build_prompt(content_item)

      expect(prompt[:model]).to be_a(Hash)
      expect(prompt[:model]["name"]).to be_present
    end

    context "with very long extracted text" do
      let(:content_item) do
        build(:content_item,
          site: site,
          source: source,
          title: "Test",
          url_canonical: "https://example.com/test",
          description: "Test",
          extracted_text: "Word " * 5000 # ~25000 chars
        )
      end

      it "truncates extracted text to MAX_TEXT_LENGTH" do
        prompt = manager.build_prompt(content_item)

        # The text should be truncated with "..." appended
        expect(prompt[:user_prompt].length).to be < 30000
      end
    end

    context "with nil content_item fields" do
      let(:content_item) do
        build(:content_item,
          site: site,
          source: source,
          title: nil,
          url_canonical: "https://example.com/test",
          description: nil,
          extracted_text: nil
        )
      end

      it "handles nil values gracefully" do
        prompt = manager.build_prompt(content_item)

        expect(prompt[:user_prompt]).to be_present
        # Should not contain "nil" string
        expect(prompt[:user_prompt]).not_to include("nil")
      end
    end
  end

  describe "#model_config" do
    let(:manager) { described_class.new(version: "v1.0.0") }

    it "returns the model configuration" do
      config = manager.model_config

      expect(config).to be_a(Hash)
      expect(config["name"]).to eq("gpt-4o-mini")
      expect(config["max_tokens"]).to be_a(Integer)
      expect(config["temperature"]).to be_a(Numeric)
    end
  end

  describe "#constraints" do
    let(:manager) { described_class.new(version: "v1.0.0") }

    it "returns the output constraints" do
      constraints = manager.constraints

      expect(constraints).to be_a(Hash)
      expect(constraints["max_summary_length"]).to eq(280)
      expect(constraints["max_why_it_matters_length"]).to eq(500)
      expect(constraints["max_suggested_tags"]).to eq(5)
    end
  end
end
