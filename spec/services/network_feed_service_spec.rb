# frozen_string_literal: true

require "rails_helper"

RSpec.describe NetworkFeedService do
  let(:tenant) { create(:tenant) }
  let!(:site1) { create(:site, tenant: tenant, status: :enabled) }
  let!(:site2) { create(:site, tenant: tenant, status: :enabled) }
  let!(:disabled_site) { create(:site, tenant: tenant, status: :disabled) }

  describe ".sites_directory" do
    it "returns enabled sites for the tenant" do
      result = described_class.sites_directory(tenant: tenant)

      expect(result).to include(site1, site2)
      expect(result).not_to include(disabled_site)
    end

    it "orders sites by name" do
      site1.update!(name: "Zebra Site")
      site2.update!(name: "Alpha Site")

      result = described_class.sites_directory(tenant: tenant)

      expect(result.first.name).to eq("Alpha Site")
      expect(result.last.name).to eq("Zebra Site")
    end

    it "does not return sites from other tenants" do
      other_tenant = create(:tenant)
      other_site = create(:site, tenant: other_tenant, status: :enabled)

      result = described_class.sites_directory(tenant: tenant)

      expect(result).not_to include(other_site)
    end

    it "caches the result" do
      expect(Rails.cache).to receive(:fetch).with(
        /network_feed:sites:#{tenant.id}/,
        expires_in: 5.minutes
      ).and_call_original

      described_class.sites_directory(tenant: tenant)
    end
  end

  describe ".recent_content" do
    let(:source) { create(:source, site: site1) }

    before do
      create_list(:content_item, 3, site: site1, source: source, published_at: 1.day.ago)
      create_list(:content_item, 2, site: site2, published_at: 2.days.ago)
      create(:content_item, site: disabled_site, published_at: 1.hour.ago)
    end

    it "returns published content from enabled sites" do
      result = described_class.recent_content(tenant: tenant, limit: 10)

      expect(result.count).to eq(5)
      expect(result.map(&:site_id)).to all(be_in([ site1.id, site2.id ]))
    end

    it "does not return content from disabled sites" do
      result = described_class.recent_content(tenant: tenant, limit: 10)

      expect(result.map(&:site_id)).not_to include(disabled_site.id)
    end

    it "orders content by published_at descending" do
      result = described_class.recent_content(tenant: tenant, limit: 10)

      published_dates = result.map(&:published_at)
      expect(published_dates).to eq(published_dates.sort.reverse)
    end

    it "respects the limit parameter" do
      result = described_class.recent_content(tenant: tenant, limit: 2)

      expect(result.count).to eq(2)
    end

    it "respects the offset parameter" do
      all_content = described_class.recent_content(tenant: tenant, limit: 10)
      offset_content = described_class.recent_content(tenant: tenant, limit: 10, offset: 2)

      expect(offset_content.first).to eq(all_content[2])
    end

    it "does not return unpublished content" do
      unpublished = create(:content_item, site: site1, published_at: nil)

      result = described_class.recent_content(tenant: tenant, limit: 10)

      expect(result).not_to include(unpublished)
    end

    it "does not return hidden content" do
      hidden = create(:content_item, site: site1, published_at: 1.hour.ago, hidden_at: Time.current)

      result = described_class.recent_content(tenant: tenant, limit: 10)

      expect(result).not_to include(hidden)
    end
  end

  describe ".network_stats" do
    let(:source) { create(:source, site: site1, tenant: tenant) }
    let(:category) { create(:category, site: site1, tenant: tenant) }

    before do
      3.times { create(:content_item, site: site1, source: source, published_at: 1.day.ago) }
      2.times { create(:listing, site: site1, tenant: tenant, category: category, published_at: 1.day.ago) }
    end

    it "returns site count for enabled sites" do
      # Count enabled sites excluding disabled ones
      enabled_count = Site.unscoped.where(tenant: tenant, status: :enabled).count

      result = described_class.network_stats(tenant: tenant)

      expect(result[:site_count]).to eq(enabled_count)
    end

    it "returns content count" do
      result = described_class.network_stats(tenant: tenant)

      expect(result[:content_count]).to eq(3)
    end

    it "returns listing count" do
      result = described_class.network_stats(tenant: tenant)

      expect(result[:listing_count]).to eq(2)
    end

    it "caches the result" do
      expect(Rails.cache).to receive(:fetch).with(
        /network_feed:stats:#{tenant.id}/,
        expires_in: 10.minutes
      ).and_call_original

      described_class.network_stats(tenant: tenant)
    end
  end
end
