# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sitemaps", type: :request do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:category) { create(:category, site: site, tenant: tenant) }

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
  end

  describe "GET /sitemap.xml" do
    it "returns XML sitemap index" do
      get sitemap_path(format: :xml)

      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("application/xml")
    end

    it "includes links to sub-sitemaps" do
      get sitemap_path(format: :xml)

      expect(response.body).to include("sitemapindex")
      expect(response.body).to include("sitemap/main")
      expect(response.body).to include("sitemap/entries")
      expect(response.body).to include("sitemap/content")
    end
  end

  describe "GET /sitemap/main.xml" do
    it "returns XML urlset" do
      get sitemap_main_path(format: :xml)

      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("application/xml")
    end

    it "includes home page" do
      get sitemap_main_path(format: :xml)

      expect(response.body).to include("urlset")
      expect(response.body).to include("<loc>http://#{tenant.hostname}/</loc>")
    end

    it "includes categories" do
      category # create category

      get sitemap_main_path(format: :xml)

      expect(response.body).to include(category_url(category))
    end
  end

  describe "GET /sitemap/entries.xml" do
    let!(:published_listing) do
      create(:entry, :directory, site: site, category: category, published_at: 1.day.ago)
    end

    let!(:unpublished_listing) do
      create(:entry, :directory, site: site, category: category, published_at: nil)
    end

    it "returns XML urlset" do
      get sitemap_listings_path(format: :xml)

      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("application/xml")
    end

    it "includes published entries" do
      get sitemap_listings_path(format: :xml)

      expect(response.body).to include(listing_url(published_listing))
    end

    it "excludes unpublished entries" do
      get sitemap_listings_path(format: :xml)

      expect(response.body).not_to include(listing_url(unpublished_listing))
    end
  end

  describe "GET /sitemap/content.xml" do
    let(:source) { create(:source, site: site) }
    let!(:published_content) do
      create(:entry, :feed, :published, site: site, source: source)
    end

    let!(:hidden_content) do
      create(:entry, :feed, :published, :hidden, site: site, source: source)
    end

    it "returns XML urlset" do
      get sitemap_content_path(format: :xml)

      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("application/xml")
    end

    it "includes published content" do
      get sitemap_content_path(format: :xml)

      expect(response.body).to include(published_content.url_canonical)
    end

    it "excludes hidden content" do
      get sitemap_content_path(format: :xml)

      expect(response.body).not_to include(hidden_content.url_canonical)
    end
  end
end
