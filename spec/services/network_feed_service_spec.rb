# frozen_string_literal: true

require "rails_helper"

RSpec.describe NetworkFeedService do
  let!(:root_tenant) { create(:tenant, slug: "root", status: :enabled) }
  let!(:root_site) { create(:site, tenant: root_tenant, status: :enabled, name: "Root Site") }
  let!(:tenant1) { create(:tenant, status: :enabled) }
  let!(:tenant2) { create(:tenant, status: :enabled) }
  let!(:disabled_tenant) { create(:tenant, status: :disabled) }
  let!(:site1) { create(:site, tenant: tenant1, status: :enabled, name: "Alpha Site") }
  let!(:site2) { create(:site, tenant: tenant2, status: :enabled, name: "Zebra Site") }
  let!(:disabled_site) { create(:site, tenant: disabled_tenant, status: :enabled) }
  let!(:site_in_disabled_tenant) { create(:site, tenant: disabled_tenant, status: :disabled) }

  describe ".sites_directory" do
    it "returns enabled sites from all enabled tenants except root" do
      result = described_class.sites_directory(tenant: root_tenant)

      expect(result).to include(site1, site2)
      expect(result).not_to include(root_site)
      expect(result).not_to include(disabled_site)
    end

    it "orders sites by name" do
      result = described_class.sites_directory(tenant: root_tenant)

      expect(result.first.name).to eq("Alpha Site")
      expect(result.last.name).to eq("Zebra Site")
    end

    it "excludes sites from disabled tenants" do
      result = described_class.sites_directory(tenant: root_tenant)

      expect(result).not_to include(disabled_site)
    end

    it "excludes the root tenant's site" do
      result = described_class.sites_directory(tenant: root_tenant)

      expect(result).not_to include(root_site)
    end

    it "caches the result" do
      expect(Rails.cache).to receive(:fetch).with(
        /network_feed:sites:network/,
        expires_in: 5.minutes
      ).and_call_original

      described_class.sites_directory(tenant: root_tenant)
    end
  end

  describe ".recent_content" do
    let(:source1) { create(:source, site: site1) }
    let(:source2) { create(:source, site: site2) }
    let(:root_source) { create(:source, site: root_site) }

    before do
      create_list(:content_item, 3, site: site1, source: source1, published_at: 1.day.ago)
      create_list(:content_item, 2, site: site2, source: source2, published_at: 2.days.ago)
      create(:content_item, site: root_site, source: root_source, published_at: 1.hour.ago)
      create(:content_item, site: disabled_site, published_at: 30.minutes.ago)
    end

    it "returns published content from enabled sites except root" do
      result = described_class.recent_content(tenant: root_tenant, limit: 10)

      expect(result.count).to eq(5)
      expect(result.map(&:site_id)).to all(be_in([ site1.id, site2.id ]))
    end

    it "does not return content from root site" do
      result = described_class.recent_content(tenant: root_tenant, limit: 10)

      expect(result.map(&:site_id)).not_to include(root_site.id)
    end

    it "does not return content from disabled tenants" do
      result = described_class.recent_content(tenant: root_tenant, limit: 10)

      expect(result.map(&:site_id)).not_to include(disabled_site.id)
    end

    it "orders content by published_at descending" do
      result = described_class.recent_content(tenant: root_tenant, limit: 10)

      published_dates = result.map(&:published_at)
      expect(published_dates).to eq(published_dates.sort.reverse)
    end

    it "respects the limit parameter" do
      result = described_class.recent_content(tenant: root_tenant, limit: 2)

      expect(result.count).to eq(2)
    end

    it "respects the offset parameter" do
      all_content = described_class.recent_content(tenant: root_tenant, limit: 10)
      offset_content = described_class.recent_content(tenant: root_tenant, limit: 10, offset: 2)

      expect(offset_content.first).to eq(all_content[2])
    end

    it "does not return unpublished content" do
      unpublished = create(:content_item, site: site1, source: source1, published_at: nil)

      result = described_class.recent_content(tenant: root_tenant, limit: 10)

      expect(result).not_to include(unpublished)
    end

    it "does not return hidden content" do
      hidden = create(:content_item, site: site1, source: source1, published_at: 1.hour.ago, hidden_at: Time.current)

      result = described_class.recent_content(tenant: root_tenant, limit: 10)

      expect(result).not_to include(hidden)
    end
  end

  describe ".network_stats" do
    let(:source1) { create(:source, site: site1, tenant: tenant1) }
    let(:category1) { create(:category, site: site1, tenant: tenant1) }

    before do
      3.times { create(:content_item, site: site1, source: source1, published_at: 1.day.ago) }
      2.times { create(:listing, site: site1, tenant: tenant1, category: category1, published_at: 1.day.ago) }
    end

    it "returns site count for enabled sites except root" do
      result = described_class.network_stats(tenant: root_tenant)

      # Should include at least site1 and site2, excluding root_site and disabled tenant sites
      expect(result[:site_count]).to be >= 2
    end

    it "returns content count from network sites" do
      result = described_class.network_stats(tenant: root_tenant)

      expect(result[:content_count]).to eq(3)
    end

    it "returns listing count from network sites" do
      result = described_class.network_stats(tenant: root_tenant)

      expect(result[:listing_count]).to eq(2)
    end

    it "caches the result" do
      expect(Rails.cache).to receive(:fetch).with(
        /network_feed:stats:network/,
        expires_in: 10.minutes
      ).and_call_original

      described_class.network_stats(tenant: root_tenant)
    end
  end
end
