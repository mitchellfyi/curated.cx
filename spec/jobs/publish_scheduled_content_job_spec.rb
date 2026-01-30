# frozen_string_literal: true

require "rails_helper"

RSpec.describe PublishScheduledContentJob, type: :job do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:source) { create(:source, site: site) }
  let(:category) { create(:category, tenant: tenant, site: site) }

  describe "#perform" do
    context "with due ContentItems" do
      let!(:due_item) do
        create(:content_item, :due_for_publishing, site: site, source: source, title: "Due Content")
      end

      it "publishes content items that are due for publishing" do
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

        expect(Rails.logger).to have_received(:info).with(/Published scheduled ContentItem #{due_item.id}/)
      end
    end

    context "with due Listings" do
      let!(:due_listing) do
        create(:listing, :due_for_publishing, tenant: tenant, category: category, title: "Due Listing")
      end

      it "publishes listings that are due for publishing" do
        freeze_time do
          described_class.perform_now

          due_listing.reload
          expect(due_listing.published_at).to be_within(1.second).of(Time.current)
          expect(due_listing.scheduled_for).to be_nil
        end
      end

      it "logs the publish action" do
        allow(Rails.logger).to receive(:info)

        described_class.perform_now

        expect(Rails.logger).to have_received(:info).with(/Published scheduled Listing #{due_listing.id}/)
      end
    end

    context "with future scheduled items" do
      let!(:scheduled_content) { create(:content_item, :scheduled, site: site, source: source) }
      let!(:scheduled_listing) { create(:listing, :scheduled, tenant: tenant, category: category) }

      it "does not publish future scheduled content items" do
        described_class.perform_now

        scheduled_content.reload
        expect(scheduled_content.published_at).to be_nil
        expect(scheduled_content.scheduled_for).to be_present
      end

      it "does not publish future scheduled listings" do
        described_class.perform_now

        scheduled_listing.reload
        expect(scheduled_listing.published_at).to be_nil
        expect(scheduled_listing.scheduled_for).to be_present
      end
    end

    context "with already published items" do
      let!(:published_content) { create(:content_item, :published, site: site, source: source) }
      let!(:published_listing) { create(:listing, :published, tenant: tenant, category: category) }

      it "does not modify already published content items" do
        original_published_at = published_content.published_at

        described_class.perform_now

        published_content.reload
        expect(published_content.published_at).to eq(original_published_at)
      end

      it "does not modify already published listings" do
        original_published_at = published_listing.published_at

        described_class.perform_now

        published_listing.reload
        expect(published_listing.published_at).to eq(original_published_at)
      end
    end

    context "when an error occurs during ContentItem publishing" do
      let!(:due_item) do
        create(:content_item, :due_for_publishing, site: site, source: source, title: "Problematic Content")
      end

      before do
        allow_any_instance_of(ContentItem).to receive(:update!).and_raise(StandardError, "Test error")
      end

      it "logs the error" do
        allow(Rails.logger).to receive(:error)

        described_class.perform_now

        expect(Rails.logger).to have_received(:error).with(/Failed to publish scheduled ContentItem #{due_item.id}/)
      end

      it "continues processing other items" do
        # Create another due item after the problematic one
        due_listing = create(:listing, :due_for_publishing, tenant: tenant, category: category)

        described_class.perform_now

        # The listing should still be processed
        due_listing.reload
        expect(due_listing.published_at).to be_present
      end
    end

    context "when an error occurs during Listing publishing" do
      let!(:due_listing) do
        create(:listing, :due_for_publishing, tenant: tenant, category: category, title: "Problematic Listing")
      end

      before do
        allow_any_instance_of(Listing).to receive(:update!).and_raise(StandardError, "Test error")
      end

      it "logs the error" do
        allow(Rails.logger).to receive(:error)

        described_class.perform_now

        expect(Rails.logger).to have_received(:error).with(/Failed to publish scheduled Listing #{due_listing.id}/)
      end
    end

    context "tenant context" do
      let!(:due_item) do
        create(:content_item, :due_for_publishing, site: site, source: source, title: "Tenant Test Content")
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
          create(:content_item, :due_for_publishing, site: site, source: source)
        end

        expect { described_class.perform_now }.not_to raise_error

        expect(ContentItem.where.not(published_at: nil).count).to eq(5)
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
