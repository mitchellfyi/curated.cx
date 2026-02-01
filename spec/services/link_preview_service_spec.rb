# frozen_string_literal: true

require "rails_helper"

RSpec.describe LinkPreviewService do
  describe ".extract" do
    it "delegates to instance method" do
      service = instance_double(described_class)
      allow(described_class).to receive(:new).with("https://example.com").and_return(service)
      allow(service).to receive(:extract).and_return({ "url" => "https://example.com" })

      result = described_class.extract("https://example.com")
      expect(result).to eq({ "url" => "https://example.com" })
    end
  end

  describe "#extract" do
    let(:url) { "https://example.com/article" }
    let(:service) { described_class.new(url) }

    context "when page is successfully fetched" do
      let(:mock_images) { double("Images", best: "https://example.com/image.jpg") }
      let(:mock_page) do
        double(
          "MetaInspector",
          url: url,
          title: "Example Article",
          description: "This is an example article description",
          images: mock_images,
          meta_tags: { "property" => { "og:site_name" => [ "Example Site" ] } },
          host: "example.com"
        )
      end

      before do
        allow(MetaInspector).to receive(:new).and_return(mock_page)
      end

      it "returns extracted metadata" do
        result = service.extract

        expect(result["url"]).to eq(url)
        expect(result["title"]).to eq("Example Article")
        expect(result["description"]).to eq("This is an example article description")
        expect(result["image"]).to eq("https://example.com/image.jpg")
        expect(result["site_name"]).to eq("Example Site")
      end

      it "excludes nil values" do
        allow(mock_page).to receive(:title).and_return(nil)
        allow(mock_page).to receive(:description).and_return("")

        result = service.extract

        expect(result).not_to have_key("title")
        expect(result).not_to have_key("description")
      end

      it "uses correct timeout and headers" do
        service.extract

        expect(MetaInspector).to have_received(:new).with(
          url,
          hash_including(
            timeout: LinkPreviewService::TIMEOUT,
            headers: { "User-Agent" => LinkPreviewService::USER_AGENT }
          )
        )
      end
    end

    context "when page has no og:site_name" do
      let(:mock_images) { double("Images", best: nil) }
      let(:mock_page) do
        double(
          "MetaInspector",
          url: url,
          title: "Example Article",
          description: nil,
          images: mock_images,
          meta_tags: { "property" => {} },
          host: "example.com"
        )
      end

      before do
        allow(MetaInspector).to receive(:new).and_return(mock_page)
      end

      it "falls back to host for site_name" do
        result = service.extract

        expect(result["site_name"]).to eq("example.com")
      end
    end

    context "when timeout occurs" do
      before do
        allow(MetaInspector).to receive(:new).and_raise(MetaInspector::TimeoutError, "Request timed out")
      end

      it "raises ExtractionError" do
        expect { service.extract }.to raise_error(
          LinkPreviewService::ExtractionError,
          /Failed to fetch URL/
        )
      end
    end

    context "when request error occurs" do
      before do
        allow(MetaInspector).to receive(:new).and_raise(MetaInspector::RequestError, "Connection refused")
      end

      it "raises ExtractionError" do
        expect { service.extract }.to raise_error(
          LinkPreviewService::ExtractionError,
          /Failed to fetch URL/
        )
      end
    end

    context "when unexpected error occurs" do
      before do
        allow(MetaInspector).to receive(:new).and_raise(StandardError, "Something went wrong")
      end

      it "raises ExtractionError and logs warning" do
        allow(Rails.logger).to receive(:warn)

        expect { service.extract }.to raise_error(
          LinkPreviewService::ExtractionError,
          /Extraction failed/
        )
        expect(Rails.logger).to have_received(:warn).with(/LinkPreviewService error/)
      end
    end

    context "with real HTTP requests", :vcr do
      # These tests would use VCR cassettes in a real test suite
      # For now, we'll skip them and rely on mocked tests
    end
  end

  describe "constants" do
    it "has a reasonable timeout" do
      expect(LinkPreviewService::TIMEOUT).to be_between(5, 30)
    end

    it "has a user agent string" do
      expect(LinkPreviewService::USER_AGENT).to include("Curated.cx")
    end
  end
end
