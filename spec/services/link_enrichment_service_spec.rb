# frozen_string_literal: true

require "rails_helper"

RSpec.describe LinkEnrichmentService do
  describe ".enrich" do
    it "delegates to instance method" do
      service = instance_double(described_class)
      allow(described_class).to receive(:new).with("https://example.com").and_return(service)
      allow(service).to receive(:enrich).and_return({ title: "Example" })

      result = described_class.enrich("https://example.com")
      expect(result).to eq({ title: "Example" })
    end
  end

  describe "#enrich" do
    let(:url) { "https://example.com/article" }
    let(:service) { described_class.new(url) }

    context "when page is successfully fetched" do
      let(:mock_images) { double("Images", best: "https://example.com/og-image.jpg") }
      let(:mock_body) { double("Body", text: "This is a sample article with enough words to count properly") }
      let(:mock_parsed) { double("Parsed", css: mock_body) }
      let(:mock_favicon_link) { double("Link", :[] => "/favicon.ico") }
      let(:mock_favicon_links) { [ mock_favicon_link ] }
      let(:mock_page) do
        double(
          "MetaInspector",
          best_title: "Example Article Title",
          best_description: "This is an example article description",
          images: mock_images,
          meta_tags: {
            "name" => {
              "author" => [ "John Doe" ],
              "msapplication-TileImage" => nil
            },
            "property" => {
              "article:published_time" => [ "2026-01-15T10:00:00Z" ],
              "article:author" => [ "John Doe" ]
            }
          },
          host: "example.com",
          parsed: mock_parsed
        )
      end

      before do
        allow(MetaInspector).to receive(:new).and_return(mock_page)
        allow(mock_parsed).to receive(:css).with("body").and_return(mock_body)
        allow(mock_parsed).to receive(:css).with('link[rel~="icon"], link[rel="shortcut icon"]').and_return(mock_favicon_links)
        allow(mock_parsed).to receive(:css).with("script, style, nav, header, footer, aside, .sidebar, .nav, .menu, .comments").and_return([])
        allow(mock_parsed).to receive(:at_css).and_return(nil)
        allow(mock_parsed).to receive(:at_css).with("body").and_return(mock_body)
        allow(mock_body).to receive(:text).and_return("This is a sample article with enough words to count properly")
      end

      it "returns enriched metadata" do
        result = service.enrich

        expect(result[:title]).to eq("Example Article Title")
        expect(result[:description]).to eq("This is an example article description")
        expect(result[:og_image_url]).to eq("https://example.com/og-image.jpg")
        expect(result[:author_name]).to eq("John Doe")
        expect(result[:published_at]).to eq("2026-01-15T10:00:00Z")
        expect(result[:domain]).to eq("example.com")
        expect(result[:word_count]).to be_a(Integer)
        expect(result[:word_count]).to be > 0
        expect(result[:read_time_minutes]).to be_a(Integer)
        expect(result[:read_time_minutes]).to be >= 1
      end

      it "returns favicon URL" do
        result = service.enrich

        expect(result[:favicon_url]).to eq("https://example.com/favicon.ico")
      end

      it "excludes nil values" do
        allow(mock_page).to receive(:best_title).and_return(nil)
        allow(mock_page).to receive(:best_description).and_return("")
        allow(mock_images).to receive(:best).and_return(nil)

        result = service.enrich

        expect(result).not_to have_key(:title)
        expect(result).not_to have_key(:description)
        expect(result).not_to have_key(:og_image_url)
      end

      it "uses correct timeout and headers" do
        service.enrich

        expect(MetaInspector).to have_received(:new).with(
          url,
          hash_including(
            timeout: LinkEnrichmentService::TIMEOUT,
            headers: { "User-Agent" => LinkEnrichmentService::USER_AGENT }
          )
        )
      end
    end

    context "when page has no author meta tag" do
      let(:mock_images) { double("Images", best: nil) }
      let(:mock_body) { double("Body", text: "Some text") }
      let(:mock_parsed) { double("Parsed") }
      let(:mock_page) do
        double(
          "MetaInspector",
          best_title: "Title",
          best_description: nil,
          images: mock_images,
          meta_tags: {
            "name" => {},
            "property" => {
              "article:author" => [ "Jane Smith" ]
            }
          },
          host: "example.com",
          parsed: mock_parsed
        )
      end

      before do
        allow(MetaInspector).to receive(:new).and_return(mock_page)
        allow(mock_parsed).to receive(:css).with("body").and_return(mock_body)
        allow(mock_parsed).to receive(:css).with('link[rel~="icon"], link[rel="shortcut icon"]').and_return([])
        allow(mock_parsed).to receive(:css).with("script, style, nav, header, footer, aside, .sidebar, .nav, .menu, .comments").and_return([])
        allow(mock_parsed).to receive(:at_css).and_return(nil)
        allow(mock_parsed).to receive(:at_css).with("body").and_return(mock_body)
      end

      it "falls back to article:author" do
        result = service.enrich

        expect(result[:author_name]).to eq("Jane Smith")
      end
    end

    context "when page has no body text" do
      let(:mock_images) { double("Images", best: nil) }
      let(:mock_parsed) { double("Parsed") }
      let(:mock_page) do
        double(
          "MetaInspector",
          best_title: "Title",
          best_description: nil,
          images: mock_images,
          meta_tags: { "name" => {}, "property" => {} },
          host: "example.com",
          parsed: mock_parsed
        )
      end

      before do
        allow(MetaInspector).to receive(:new).and_return(mock_page)
        allow(mock_parsed).to receive(:css).with("body").and_return(nil)
        allow(mock_parsed).to receive(:css).with('link[rel~="icon"], link[rel="shortcut icon"]').and_return([])
        allow(mock_parsed).to receive(:css).with("script, style, nav, header, footer, aside, .sidebar, .nav, .menu, .comments").and_return([])
        allow(mock_parsed).to receive(:at_css).and_return(nil)
      end

      it "returns nil word count and read time" do
        result = service.enrich

        expect(result[:word_count]).to eq(0)
        expect(result).not_to have_key(:read_time_minutes)
      end
    end

    context "when word count estimation produces a read time" do
      let(:mock_images) { double("Images", best: nil) }
      # 400 words = 2 minutes at 200 wpm
      let(:body_text) { ([ "word" ] * 400).join(" ") }
      let(:mock_body) { double("Body", text: body_text) }
      let(:mock_parsed) { double("Parsed") }
      let(:mock_page) do
        double(
          "MetaInspector",
          best_title: "Title",
          best_description: nil,
          images: mock_images,
          meta_tags: { "name" => {}, "property" => {} },
          host: "example.com",
          parsed: mock_parsed
        )
      end

      before do
        allow(MetaInspector).to receive(:new).and_return(mock_page)
        allow(mock_parsed).to receive(:css).with("body").and_return(mock_body)
        allow(mock_parsed).to receive(:css).with('link[rel~="icon"], link[rel="shortcut icon"]').and_return([])
        allow(mock_parsed).to receive(:css).with("script, style, nav, header, footer, aside, .sidebar, .nav, .menu, .comments").and_return([])
        allow(mock_parsed).to receive(:at_css).and_return(nil)
        allow(mock_parsed).to receive(:at_css).with("body").and_return(mock_body)
      end

      it "calculates read time based on word count" do
        result = service.enrich

        expect(result[:word_count]).to eq(400)
        expect(result[:read_time_minutes]).to eq(2)
      end
    end

    context "when timeout occurs" do
      before do
        allow(MetaInspector).to receive(:new).and_raise(MetaInspector::TimeoutError, "Request timed out")
      end

      it "raises EnrichmentError" do
        expect { service.enrich }.to raise_error(
          LinkEnrichmentService::EnrichmentError,
          /Failed to fetch URL/
        )
      end
    end

    context "when request error occurs" do
      before do
        allow(MetaInspector).to receive(:new).and_raise(MetaInspector::RequestError, "Connection refused")
      end

      it "raises EnrichmentError" do
        expect { service.enrich }.to raise_error(
          LinkEnrichmentService::EnrichmentError,
          /Failed to fetch URL/
        )
      end
    end

    context "when unexpected error occurs" do
      before do
        allow(MetaInspector).to receive(:new).and_raise(StandardError, "Something went wrong")
      end

      it "raises EnrichmentError and logs warning" do
        allow(Rails.logger).to receive(:warn)

        expect { service.enrich }.to raise_error(
          LinkEnrichmentService::EnrichmentError,
          /Enrichment failed/
        )
        expect(Rails.logger).to have_received(:warn).with(/LinkEnrichmentService error/)
      end
    end
  end

  describe "constants" do
    it "has a reasonable timeout" do
      expect(LinkEnrichmentService::TIMEOUT).to be_between(5, 30)
    end

    it "has a user agent string" do
      expect(LinkEnrichmentService::USER_AGENT).to include("Curated.cx")
    end

    it "has a words per minute constant" do
      expect(LinkEnrichmentService::WORDS_PER_MINUTE).to eq(200)
    end
  end
end
