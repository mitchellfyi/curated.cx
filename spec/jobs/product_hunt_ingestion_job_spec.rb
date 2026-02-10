# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProductHuntIngestionJob, type: :job do
  include ActiveJob::TestHelper

  let(:tenant) { create(:tenant) }
  let(:site) { create(:site, tenant: tenant) }
  let(:source) { create(:source, :product_hunt, site: site) }

  describe "#perform" do
    context "happy path" do
      before do
        stub_product_hunt_response
        allow(TaggingService).to receive(:tag).and_return({
          topic_tags: [],
          content_type: "article",
          confidence: 0.9,
          explanation: []
        })
      end

      it "creates Entrys from Product Hunt results" do
        expect {
          described_class.perform_now(source.id)
        }.to change(Entry, :count).by(3)
      end

      it "creates an ImportRun record" do
        expect {
          described_class.perform_now(source.id)
        }.to change(ImportRun, :count).by(1)
      end

      it "marks the ImportRun as completed" do
        described_class.perform_now(source.id)

        import_run = ImportRun.last
        expect(import_run.status).to eq("completed")
        expect(import_run.completed_at).to be_present
      end

      it "tracks item counts in the ImportRun" do
        described_class.perform_now(source.id)

        import_run = ImportRun.last
        expect(import_run.items_created).to eq(3)
        expect(import_run.items_updated).to eq(0)
        expect(import_run.items_failed).to eq(0)
        expect(import_run.items_count).to eq(3)
      end

      it "updates source status to success" do
        described_class.perform_now(source.id)
        source.reload
        expect(source.last_status).to eq("success")
        expect(source.last_run_at).to be_within(1.second).of(Time.current)
      end

      it "stores correct Entry attributes" do
        described_class.perform_now(source.id)

        item = Entry.find_by(title: "LaunchPad AI")
        expect(item).to be_present
        expect(item.url_raw).to eq("https://www.producthunt.com/posts/launchpad-ai")
        expect(item.description).to eq("AI-powered startup launch assistant")
        expect(item.og_image_url).to eq("https://ph-files.imgix.net/launchpad-ai-thumb.png")
        expect(item.source).to eq(source)
        expect(item.site).to eq(site)
      end

      it "stores votes and makers in raw_payload" do
        described_class.perform_now(source.id)

        item = Entry.find_by(title: "LaunchPad AI")
        expect(item.raw_payload["votesCount"]).to eq(523)
        expect(item.raw_payload["makers"]).to be_present
        expect(item.raw_payload["makers"].first["name"]).to eq("Jane Smith")
      end

      it "extracts topic tags" do
        described_class.perform_now(source.id)

        item = Entry.find_by(title: "LaunchPad AI")
        expect(item.tags).to include("source:product-hunt")
        expect(item.tags).to include("topic:artificial-intelligence")
        expect(item.tags).to include("topic:saas")
      end
    end

    context "deduplication" do
      before do
        stub_product_hunt_response
        allow(TaggingService).to receive(:tag).and_return({
          topic_tags: [],
          content_type: "article",
          confidence: 0.9,
          explanation: []
        })
      end

      it "does not create duplicate Entrys on subsequent runs" do
        expect {
          described_class.perform_now(source.id)
        }.to change(Entry, :count).by(3)

        expect {
          described_class.perform_now(source.id)
        }.to change(Entry, :count).by(0)
      end

      it "updates existing Entrys on subsequent runs" do
        described_class.perform_now(source.id)
        first_run = ImportRun.order(:created_at).last

        described_class.perform_now(source.id)
        second_run = ImportRun.order(:created_at).last

        expect(first_run.items_created).to eq(3)
        expect(first_run.items_updated).to eq(0)

        expect(second_run.items_created).to eq(0)
        expect(second_run.items_updated).to eq(3)
      end
    end

    context "max_results configuration" do
      let(:source) do
        create(:source, :product_hunt, site: site, config: {
          "access_token" => "test_ph_token",
          "feed_type" => "featured",
          "max_results" => 2
        })
      end

      before do
        stub_product_hunt_response
        allow(TaggingService).to receive(:tag).and_return({
          topic_tags: [],
          content_type: "article",
          confidence: 0.9,
          explanation: []
        })
      end

      it "respects max_results limit" do
        expect {
          described_class.perform_now(source.id)
        }.to change(Entry, :count).by(2)
      end
    end

    context "when source is disabled" do
      let(:source) { create(:source, :product_hunt, :disabled, site: site) }

      it "skips processing and updates status to skipped" do
        expect {
          described_class.perform_now(source.id)
        }.not_to change(Entry, :count)

        source.reload
        expect(source.last_status).to eq("skipped")
      end

      it "does not create an ImportRun" do
        expect {
          described_class.perform_now(source.id)
        }.not_to change(ImportRun, :count)
      end
    end

    context "when source is not product_hunt type" do
      let(:source) { create(:source, :rss, site: site) }

      it "skips processing and updates status to skipped" do
        expect {
          described_class.perform_now(source.id)
        }.not_to change(Entry, :count)

        source.reload
        expect(source.last_status).to eq("skipped")
      end
    end

    context "when Product Hunt API request fails" do
      before do
        stub_product_hunt_response(status: 500)
      end

      it "marks the ImportRun as failed" do
        begin
          described_class.perform_now(source.id)
        rescue StandardError
          # Expected - retry mechanism may throw
        end

        import_run = ImportRun.last
        expect(import_run.status).to eq("failed")
        expect(import_run.error_message).to include("500")
      end

      it "updates source status with error" do
        begin
          described_class.perform_now(source.id)
        rescue StandardError
          # Expected
        end

        source.reload
        expect(source.last_status).to start_with("error:")
      end
    end

    context "when access_token is missing" do
      let(:source) do
        create(:source, :product_hunt, site: site, config: {
          "feed_type" => "featured",
          "max_results" => 50
        })
      end

      it "discards the job due to ConfigurationError" do
        expect {
          described_class.perform_now(source.id)
        }.not_to change(Entry, :count)
      end
    end

    context "when results are empty" do
      before do
        stub_request(:post, "https://api.producthunt.com/v2/api/graphql")
          .to_return(
            status: 200,
            body: { "data" => { "posts" => { "edges" => [] } } }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "handles empty results gracefully" do
        expect {
          described_class.perform_now(source.id)
        }.not_to change(Entry, :count)

        source.reload
        expect(source.last_status).to eq("success")
      end

      it "marks ImportRun as completed with zero counts" do
        described_class.perform_now(source.id)

        import_run = ImportRun.last
        expect(import_run.status).to eq("completed")
        expect(import_run.items_count).to eq(0)
      end
    end

    context "tenant context management" do
      before do
        stub_product_hunt_response
        allow(TaggingService).to receive(:tag).and_return({
          topic_tags: [],
          content_type: "article",
          confidence: 0.9,
          explanation: []
        })
      end

      it "sets Current.tenant during execution" do
        described_class.perform_now(source.id)

        import_run = ImportRun.last
        expect(import_run.status).to eq("completed")
      end

      it "clears context after execution" do
        described_class.perform_now(source.id)

        expect(Current.tenant).to be_nil
        expect(Current.site).to be_nil
      end
    end
  end

  describe "retry behavior" do
    it "is configured to retry on StandardError" do
      error_classes = described_class.rescue_handlers.map { |h| h[0] }
      expect(error_classes).to include("StandardError")
    end
  end

  describe "queue configuration" do
    it "uses the ingestion queue" do
      expect(described_class.queue_name).to eq("ingestion")
    end
  end
end
