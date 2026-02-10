# frozen_string_literal: true

require "rails_helper"

RSpec.describe PublishScheduledContentJob, type: :job do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:source) { create(:source, site: site) }
  let(:category) { create(:category, tenant: tenant, site: site) }

  describe "#perform" do
    context "with due feed entries" do
      let!(:due_item) do
        create(:entry, :feed, :due_for_publishing, site: site, source: source, title: "Due Content")
      end

      it "publishes entries that are due for publishing" do
        freeze_time do
          described_class.perform_now

          due_item.reload
          expect(due_item.published_at).to be_within(1.second).of(Time.current)
          expect(due_item.scheduled_for).to be_nil
        end
      end

      it "logs the publish action" do
        allow(Rails.logger).to receive(:info)

        described_class.perform_now

        expect(Rails.logger).to have_received(:info).with(/Published scheduled content.*"type":"Entry".*"id":#{due_item.id}/)
      end
    end

    context "with due directory entries" do
      let!(:due_entry) do
        create(:entry, :directory, :due_for_publishing, tenant: tenant, category: category, title: "Due Listing")
      end

      it "publishes directory entries that are due for publishing" do
        freeze_time do
          described_class.perform_now

          due_entry.reload
          expect(due_entry.published_at).to be_within(1.second).of(Time.current)
          expect(due_entry.scheduled_for).to be_nil
        end
      end

      it "logs the publish action" do
        allow(Rails.logger).to receive(:info)

        described_class.perform_now

        expect(Rails.logger).to have_received(:info).with(/Published scheduled content.*"type":"Entry".*"id":#{due_entry.id}/)
      end
    end

    context "with future scheduled items" do
      let!(:scheduled_feed) { create(:entry, :feed, :scheduled, site: site, source: source) }
      let!(:scheduled_directory) { create(:entry, :directory, :scheduled, tenant: tenant, category: category) }

      it "does not publish future scheduled feed entries" do
        described_class.perform_now

        scheduled_feed.reload
        expect(scheduled_feed.published_at).to be_nil
        expect(scheduled_feed.scheduled_for).to be_present
      end

      it "does not publish future scheduled directory entries" do
        described_class.perform_now

        scheduled_directory.reload
        expect(scheduled_directory.published_at).to be_nil
        expect(scheduled_directory.scheduled_for).to be_present
      end
    end

    context "with already published items" do
      let!(:published_feed) { create(:entry, :feed, :published, site: site, source: source) }
      let!(:published_directory) { create(:entry, :directory, :published, tenant: tenant, category: category) }

      it "does not modify already published feed entries" do
        original_published_at = published_feed.published_at

        described_class.perform_now

        published_feed.reload
        expect(published_feed.published_at).to eq(original_published_at)
      end

      it "does not modify already published directory entries" do
        original_published_at = published_directory.published_at

        described_class.perform_now

        published_directory.reload
        expect(published_directory.published_at).to eq(original_published_at)
      end
    end

    context "when an error occurs during feed entry publishing" do
      let!(:due_item) do
        create(:entry, :feed, :due_for_publishing, site: site, source: source, title: "Problematic Content")
      end

      before do
        allow_any_instance_of(Entry).to receive(:update!).and_raise(StandardError, "Test error")
      end

      it "logs the error" do
        allow(Rails.logger).to receive(:warn)

        described_class.perform_now

        expect(Rails.logger).to have_received(:warn).with(/Failed to publish scheduled content.*"type":"Entry".*"id":#{due_item.id}/)
      end

      it "continues processing other items" do
        # Create another due item after the problematic one
        due_entry = create(:entry, :directory, :due_for_publishing, tenant: tenant, category: category)

        described_class.perform_now

        # The directory entry should still be processed
        due_entry.reload
        expect(due_entry.published_at).to be_present
      end
    end

    context "when an error occurs during directory entry publishing" do
      let!(:due_entry) do
        create(:entry, :directory, :due_for_publishing, tenant: tenant, category: category, title: "Problematic Listing")
      end

      before do
        allow_any_instance_of(Entry).to receive(:update!).and_raise(StandardError, "Test error")
      end

      it "logs the error" do
        allow(Rails.logger).to receive(:warn)

        described_class.perform_now

        expect(Rails.logger).to have_received(:warn).with(/Failed to publish scheduled content.*"type":"Entry".*"id":#{due_entry.id}/)
      end
    end

    context "tenant context" do
      let!(:due_item) do
        create(:entry, :feed, :due_for_publishing, site: site, source: source, title: "Tenant Test Content")
      end

      it "wraps processing in correct tenant context" do
        expect(ActsAsTenant).to receive(:with_tenant).with(tenant).and_call_original

        described_class.perform_now
      end
    end

    context "with no due items" do
      it "completes without error" do
        expect { described_class.perform_now }.not_to raise_error
      end
    end

    context "batch processing" do
      it "processes items in batches" do
        # Create more items than the batch size
        5.times do
          create(:entry, :feed, :due_for_publishing, site: site, source: source)
        end

        expect { described_class.perform_now }.not_to raise_error

        expect(Entry.where.not(published_at: nil).count).to eq(5)
      end
    end
  end

  it "uses the default queue" do
    expect(described_class.new.queue_name).to eq("default")
  end

  it "can be enqueued" do
    expect {
      described_class.perform_later
    }.to have_enqueued_job(described_class)
  end
end
