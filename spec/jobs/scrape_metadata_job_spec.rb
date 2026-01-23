# frozen_string_literal: true

require "rails_helper"

RSpec.describe ScrapeMetadataJob, type: :job do
  include ActiveJob::TestHelper

  let(:tenant) { create(:tenant) }
  let(:site) { create(:site, tenant: tenant) }
  let(:category) { create(:category, tenant: tenant, site: site) }
  let(:listing) do
    create(:listing,
      tenant: tenant,
      site: site,
      category: category,
      url_raw: "https://example.com/article",
      url_canonical: "https://example.com/article",
      title: "Original Title")
  end
  let(:html_content) { fixture_file("sample_page.html") }

  describe "#perform" do
    context "happy path" do
      let(:mock_page) do
        instance_double(
          MetaInspector::Document,
          title: "Sample Article Title",
          description: "This is a sample article description for testing metadata extraction.",
          host: "example.com",
          body: "<html><body>Page content</body></html>",
          parsed: Nokogiri::HTML(html_content),
          images: instance_double("MetaInspector::Images", best: "https://example.com/images/article-image.jpg"),
          meta_tags: {
            "property" => {
              "article:published_time" => "2026-01-15T10:30:00Z"
            }
          }
        )
      end

      before do
        allow(MetaInspector).to receive(:new).and_return(mock_page)
      end

      it "updates listing with scraped metadata" do
        described_class.perform_now(listing.id)

        listing.reload
        expect(listing.title).to eq("Sample Article Title")
        expect(listing.description).to eq("This is a sample article description for testing metadata extraction.")
        expect(listing.image_url).to eq("https://example.com/images/article-image.jpg")
        expect(listing.site_name).to eq("example.com")
      end

      it "extracts published_at from meta tags" do
        described_class.perform_now(listing.id)

        listing.reload
        expect(listing.published_at).to eq(Time.parse("2026-01-15T10:30:00Z"))
      end

      it "extracts body HTML and text" do
        described_class.perform_now(listing.id)

        listing.reload
        expect(listing.body_html).to be_present
      end

      it "returns the listing" do
        result = described_class.perform_now(listing.id)

        expect(result).to eq(listing)
      end
    end

    context "published_at extraction" do
      it "extracts from article:published_time" do
        mock_page = instance_double(
          MetaInspector::Document,
          title: "Title",
          description: nil,
          host: "example.com",
          body: nil,
          parsed: Nokogiri::HTML("<html></html>"),
          images: instance_double("MetaInspector::Images", best: nil),
          meta_tags: {
            "property" => { "article:published_time" => "2026-01-15T10:30:00Z" }
          }
        )
        allow(MetaInspector).to receive(:new).and_return(mock_page)

        described_class.perform_now(listing.id)

        listing.reload
        expect(listing.published_at).to eq(Time.parse("2026-01-15T10:30:00Z"))
      end

      it "extracts from og:published_time as fallback" do
        mock_page = instance_double(
          MetaInspector::Document,
          title: "Title",
          description: nil,
          host: "example.com",
          body: nil,
          parsed: Nokogiri::HTML("<html></html>"),
          images: instance_double("MetaInspector::Images", best: nil),
          meta_tags: {
            "property" => { "og:published_time" => "2026-01-14T09:00:00Z" }
          }
        )
        allow(MetaInspector).to receive(:new).and_return(mock_page)

        described_class.perform_now(listing.id)

        listing.reload
        expect(listing.published_at).to eq(Time.parse("2026-01-14T09:00:00Z"))
      end

      it "extracts from JSON-LD datePublished" do
        json_ld_html = <<~HTML
          <html>
          <head>
            <script type="application/ld+json">
            {"@type": "NewsArticle", "datePublished": "2026-01-13T08:00:00Z"}
            </script>
          </head>
          </html>
        HTML

        mock_page = instance_double(
          MetaInspector::Document,
          title: "Title",
          description: nil,
          host: "example.com",
          body: nil,
          parsed: Nokogiri::HTML(json_ld_html),
          images: instance_double("MetaInspector::Images", best: nil),
          meta_tags: { "property" => {} }
        )
        allow(MetaInspector).to receive(:new).and_return(mock_page)

        described_class.perform_now(listing.id)

        listing.reload
        expect(listing.published_at).to eq(Time.parse("2026-01-13T08:00:00Z"))
      end
    end

    context "handles missing metadata gracefully" do
      let(:listing) do
        create(:listing,
          tenant: tenant,
          site: site,
          category: category,
          url_canonical: "https://example.com/article",
          title: "Existing Title",
          description: "Existing Description")
      end

      it "keeps existing values when scraped values are blank" do
        mock_page = instance_double(
          MetaInspector::Document,
          title: nil,
          description: "",
          host: "example.com",
          body: nil,
          parsed: nil,
          images: instance_double("MetaInspector::Images", best: nil),
          meta_tags: {}
        )
        allow(MetaInspector).to receive(:new).and_return(mock_page)

        described_class.perform_now(listing.id)

        listing.reload
        expect(listing.title).to eq("Existing Title")
        expect(listing.description).to eq("Existing Description")
      end
    end

    context "error handling" do
      it "logs warning and returns nil for MetaInspector timeout" do
        allow(MetaInspector).to receive(:new).and_raise(MetaInspector::TimeoutError.new("Timeout"))
        expect(Rails.logger).to receive(:warn).with(/Failed to fetch metadata/)

        result = described_class.perform_now(listing.id)

        expect(result).to be_nil
      end

      it "logs warning and returns nil for request errors" do
        allow(MetaInspector).to receive(:new).and_raise(MetaInspector::RequestError.new("Connection refused"))
        expect(Rails.logger).to receive(:warn).with(/Failed to fetch metadata/)

        result = described_class.perform_now(listing.id)

        expect(result).to be_nil
      end

      it "does not re-raise errors - prevents blocking job queue" do
        allow(MetaInspector).to receive(:new).and_raise(StandardError.new("Some error"))

        expect {
          described_class.perform_now(listing.id)
        }.not_to raise_error
      end

      it "logs error for unexpected failures" do
        allow(MetaInspector).to receive(:new).and_raise(StandardError.new("Unexpected"))
        expect(Rails.logger).to receive(:error).with(/Error in ScrapeMetadataJob/)

        described_class.perform_now(listing.id)
      end
    end

    context "tenant context management" do
      let(:mock_page) do
        instance_double(
          MetaInspector::Document,
          title: "Title",
          description: nil,
          host: "example.com",
          body: nil,
          parsed: nil,
          images: instance_double("MetaInspector::Images", best: nil),
          meta_tags: {}
        )
      end

      before do
        allow(MetaInspector).to receive(:new).and_return(mock_page)
      end

      it "sets Current.tenant during execution" do
        expect(Current).to receive(:tenant=).with(tenant).ordered
        expect(Current).to receive(:site=).with(site).ordered
        expect(Current).to receive(:tenant=).with(nil).ordered
        expect(Current).to receive(:site=).with(nil).ordered

        described_class.perform_now(listing.id)
      end

      it "clears context even when error occurs" do
        allow(MetaInspector).to receive(:new).and_raise(StandardError.new("Error"))

        expect(Current).to receive(:tenant=).with(nil).at_least(:once)
        expect(Current).to receive(:site=).with(nil).at_least(:once)

        described_class.perform_now(listing.id)
      end
    end

    context "MetaInspector configuration" do
      before do
        allow(MetaInspector).to receive(:new).and_call_original
        stub_request(:get, "https://example.com/article")
          .to_return(status: 200, body: html_content, headers: { "Content-Type" => "text/html" })
      end

      it "configures timeout" do
        expect(MetaInspector).to receive(:new).with(
          anything,
          hash_including(timeout: 20)
        ).and_call_original

        described_class.perform_now(listing.id)
      end

      it "configures retries" do
        expect(MetaInspector).to receive(:new).with(
          anything,
          hash_including(retries: 2)
        ).and_call_original

        described_class.perform_now(listing.id)
      end

      it "sets custom User-Agent" do
        expect(MetaInspector).to receive(:new).with(
          anything,
          hash_including(headers: hash_including("User-Agent" => /Curated\.cx/))
        ).and_call_original

        described_class.perform_now(listing.id)
      end
    end
  end

  describe "retry behavior" do
    it "is configured to retry on StandardError" do
      expect(described_class.rescue_handlers).to include(
        a_hash_including("error_class" => "StandardError")
      )
    end

    it "uses exponential backoff" do
      handler = described_class.rescue_handlers.find { |h| h["error_class"] == "StandardError" }
      expect(handler["wait"]).to eq(:exponentially_longer)
    end

    it "retries up to 3 times" do
      handler = described_class.rescue_handlers.find { |h| h["error_class"] == "StandardError" }
      expect(handler["attempts"]).to eq(3)
    end
  end

  describe "queue configuration" do
    it "uses the scraping queue" do
      expect(described_class.queue_name).to eq("scraping")
    end
  end
end
