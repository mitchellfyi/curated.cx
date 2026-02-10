# frozen_string_literal: true

require "rails_helper"

RSpec.describe TenantHomepageService do
  let(:tenant) { create(:tenant) }
  let(:site) { create(:site, tenant: tenant) }

  subject(:service) { described_class.new(site: site, tenant: tenant) }

  describe "#root_tenant_data" do
    let(:root_tenant) { create(:tenant, slug: "root") }
    let(:root_site) { create(:site, tenant: root_tenant) }

    subject(:service) { described_class.new(site: root_site, tenant: root_tenant) }

    before do
      create(:site, tenant: root_tenant, status: :enabled)
    end

    it "returns sites from NetworkFeedService" do
      result = service.root_tenant_data

      expect(result[:sites]).to be_an(Array)
    end

    it "returns network_feed from NetworkFeedService" do
      result = service.root_tenant_data

      expect(result[:network_feed]).to be_an(Array)
    end

    it "returns network_stats from NetworkFeedService" do
      result = service.root_tenant_data

      expect(result[:network_stats]).to be_a(Hash)
      expect(result[:network_stats]).to have_key(:site_count)
    end
  end

  describe "#tenant_data" do
    it "returns entries from FeedRankingService" do
      result = service.tenant_data

      expect(result[:entries]).not_to be_nil
    end

    it "returns categories_with_entries as an array" do
      result = service.tenant_data

      expect(result[:categories_with_entries]).to be_an(Array)
    end

    context "with categories and entries" do
      let!(:category) { create(:category, tenant: tenant, site: site) }
      let!(:entry) { create(:entry, :directory, tenant: tenant, site: site, category: category, published_at: 1.day.ago) }

      it "includes categories with their entries" do
        result = service.tenant_data

        expect(result[:categories_with_entries]).not_to be_empty
        cat, entries = result[:categories_with_entries].first
        expect(cat).to eq(category)
        expect(entries).to include(entry)
      end

      it "limits entries per category to 4" do
        create_list(:entry, :directory, 5, tenant: tenant, site: site, category: category, published_at: 1.day.ago)

        result = service.tenant_data

        _cat, entries = result[:categories_with_entries].first
        expect(entries.count).to be <= 4
      end

      it "orders entries by published_at descending" do
        old_entry = create(:entry, :directory, tenant: tenant, site: site, category: category, published_at: 1.week.ago)
        new_entry = create(:entry, :directory, tenant: tenant, site: site, category: category, published_at: 1.hour.ago)

        result = service.tenant_data

        _cat, entries = result[:categories_with_entries].first
        expect(entries.first).to eq(new_entry)
      end

      it "excludes unpublished entries" do
        unpublished = create(:entry, :directory, tenant: tenant, site: site, category: category, published_at: nil)

        result = service.tenant_data

        _cat, entries = result[:categories_with_entries].first
        expect(entries).not_to include(unpublished)
      end
    end

    context "with empty categories" do
      let!(:empty_category) { create(:category, tenant: tenant, site: site) }

      it "excludes categories with no published entries" do
        result = service.tenant_data

        categories = result[:categories_with_entries].map(&:first)
        expect(categories).not_to include(empty_category)
      end
    end
  end
end
