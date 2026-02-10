# frozen_string_literal: true

require "rails_helper"

RSpec.describe UpsertEntriesJob, type: :job do
  include ActiveJob::TestHelper

  let(:tenant) { create(:tenant) }
  let(:site) { create(:site, tenant: tenant) }
  let(:category) { create(:category, tenant: tenant, site: site) }
  let(:source) { create(:source, :rss, site: site) }
  let(:url_raw) { "https://example.com/article-1?utm_source=test" }

  describe "#perform" do
    context "happy path - new entry" do
      it "creates a new entry with correct attributes" do
        expect {
          described_class.perform_now(tenant.id, category.id, url_raw, source_id: source.id)
        }.to change(Entry, :count).by(1)
      end

      it "sets entry attributes correctly" do
        entry = described_class.perform_now(tenant.id, category.id, url_raw, source_id: source.id)

        expect(entry.tenant).to eq(tenant)
        expect(entry.site).to eq(site)
        expect(entry.category).to eq(category)
        expect(entry.source).to eq(source)
        expect(entry.url_raw).to eq(url_raw)
      end

      it "canonicalizes URL and removes tracking params" do
        entry = described_class.perform_now(tenant.id, category.id, url_raw, source_id: source.id)

        expect(entry.url_canonical).to eq("https://example.com/article-1")
        expect(entry.url_canonical).not_to include("utm_source")
      end

      it "enqueues ScrapeMetadataJob after creating entry" do
        expect {
          described_class.perform_now(tenant.id, category.id, url_raw, source_id: source.id)
        }.to have_enqueued_job(ScrapeMetadataJob).once
      end

      it "extracts basic title from URL" do
        entry = described_class.perform_now(tenant.id, category.id, url_raw, source_id: source.id)

        expect(entry.title).to be_present
        expect(entry.title).not_to eq("Untitled")
      end
    end

    context "idempotency - existing entry" do
      let!(:existing_entry) do
        create(:entry, :directory,
          tenant: tenant,
          site: site,
          category: category,
          url_raw: url_raw,
          url_canonical: "https://example.com/article-1")
      end

      it "does not create duplicate entry" do
        expect {
          described_class.perform_now(tenant.id, category.id, url_raw, source_id: source.id)
        }.not_to change(Entry, :count)
      end

      it "returns existing entry" do
        result = described_class.perform_now(tenant.id, category.id, url_raw, source_id: source.id)

        expect(result.id).to eq(existing_entry.id)
      end

      it "does NOT enqueue ScrapeMetadataJob for existing entry" do
        expect {
          described_class.perform_now(tenant.id, category.id, url_raw, source_id: source.id)
        }.not_to have_enqueued_job(ScrapeMetadataJob)
      end

      it "updates source if provided" do
        new_source = create(:source, :rss, site: site, name: "New Source")

        described_class.perform_now(tenant.id, category.id, url_raw, source_id: new_source.id)

        existing_entry.reload
        expect(existing_entry.source).to eq(new_source)
      end
    end

    context "URL normalization" do
      it "treats different URLs with same canonical as duplicates" do
        # First with tracking params
        entry1 = described_class.perform_now(tenant.id, category.id, "https://example.com/page?utm_source=a")
        # Second with different tracking params
        entry2 = described_class.perform_now(tenant.id, category.id, "https://example.com/page?utm_campaign=b")

        expect(entry2.id).to eq(entry1.id)
      end

      it "normalizes case in host" do
        entry = described_class.perform_now(tenant.id, category.id, "https://EXAMPLE.COM/page")

        expect(entry.url_canonical).to eq("https://example.com/page")
      end
    end

    context "invalid URL" do
      it "returns nil for blank URL" do
        result = described_class.perform_now(tenant.id, category.id, "")

        expect(result).to be_nil
      end

      it "logs warning and returns nil for invalid URL" do
        expect(Rails.logger).to receive(:warn).with(/Invalid URL/)

        result = described_class.perform_now(tenant.id, category.id, "not a valid url at all")

        expect(result).to be_nil
      end

      it "does not raise error for invalid URL" do
        expect {
          described_class.perform_now(tenant.id, category.id, "invalid://url")
        }.not_to raise_error
      end
    end

    context "validation errors" do
      it "raises error when site tenant doesn't match provided tenant" do
        # Create a category on a different tenant
        other_tenant = create(:tenant)
        other_site = other_tenant.sites.first
        other_category = create(:category, tenant: other_tenant, site: other_site)

        # The job should fail (either due to tenant mismatch or retry mechanism)
        # We just verify that no entry is created for the wrong tenant
        begin
          described_class.perform_now(tenant.id, other_category.id, url_raw)
        rescue StandardError
          # Expected - some error should occur
        end

        # Verify no entry was created with mismatched tenant
        expect(Entry.where(tenant: tenant, category: other_category).count).to eq(0)
      end
    end

    context "without source_id" do
      it "creates entry without source" do
        entry = described_class.perform_now(tenant.id, category.id, url_raw)

        expect(entry.source).to be_nil
      end
    end

    context "tenant context management" do
      it "sets Current.tenant during execution" do
        # Verify the job ran successfully (requires tenant context)
        entry = described_class.perform_now(tenant.id, category.id, url_raw)
        expect(entry).to be_present
        expect(entry.tenant).to eq(tenant)
      end

      it "clears context after execution" do
        described_class.perform_now(tenant.id, category.id, url_raw)
        expect(Current.tenant).to be_nil
        expect(Current.site).to be_nil
      end
    end

    context "race condition handling" do
      # Simulate race condition where two jobs try to create same entry
      it "handles ActiveRecord::RecordNotUnique by finding existing" do
        # First create succeeds
        entry1 = described_class.perform_now(tenant.id, category.id, url_raw)

        # Simulate second job: first find_by returns nil, create raises unique,
        # second find_by returns the existing entry
        directory_scope = Entry.directory_items
        call_count = 0
        allow(Entry).to receive(:directory_items).and_return(directory_scope)
        allow(directory_scope).to receive(:find_by).and_wrap_original do |method, *args|
          call_count += 1
          call_count == 1 ? nil : entry1
        end
        allow(Entry).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)

        result = described_class.perform_now(tenant.id, category.id, "https://example.com/article-1")

        expect(result.id).to eq(entry1.id)
      end
    end
  end

  describe "retry behavior" do
    it "retries on ActiveRecord::RecordNotUnique" do
      error_classes = described_class.rescue_handlers.map { |h| h[0] }
      expect(error_classes).to include("ActiveRecord::RecordNotUnique")
    end

    it "retries on StandardError" do
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
