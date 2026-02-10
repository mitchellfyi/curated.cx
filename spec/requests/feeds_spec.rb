# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Feeds", type: :request do
  let(:tenant) { create(:tenant, :enabled, slug: "test") }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:source) { create(:source, site: site) }
  let(:category) { create(:category, site: site, tenant: tenant, name: "Tools") }

  before do
    Current.tenant = tenant
    Current.site = site
    host! "#{tenant.slug}.localhost"
  end

  describe "GET /feeds/content" do
    let!(:entries) do
      # Factory defaults have published_at set and hidden_at nil
      create_list(:entry, 3, :feed, source: source)
    end

    context "with RSS format" do
      it "returns RSS feed" do
        get feeds_content_path(format: :rss)

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("application/rss+xml")
      end

      it "includes content items in the feed" do
        get feeds_content_path(format: :rss)

        expect(response.body).to include("<rss")
        expect(response.body).to include(entries.first.title)
      end

      it "includes channel metadata" do
        get feeds_content_path(format: :rss)

        expect(response.body).to include("<title>")
        expect(response.body).to include("<link>")
        expect(response.body).to include("<description>")
      end
    end

    context "with Atom format" do
      it "returns Atom feed" do
        get feeds_content_path(format: :atom)

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("application/atom+xml")
      end

      it "includes content items as entries" do
        get feeds_content_path(format: :atom)

        expect(response.body).to include("<feed")
        expect(response.body).to include("<entry>")
        expect(response.body).to include(entries.first.title)
      end
    end
  end

  describe "GET /feeds/entries" do
    let!(:entries) do
      # Factory defaults create published entries (published_at is set)
      create_list(:entry, 3, :directory, site: site, category: category)
    end

    context "with RSS format" do
      it "returns RSS feed" do
        get feeds_listings_path(format: :rss)

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("application/rss+xml")
      end

      it "includes entries in the feed" do
        get feeds_listings_path(format: :rss)

        expect(response.body).to include("<rss")
        expect(response.body).to include(entries.first.title)
      end

      it "includes category information" do
        get feeds_listings_path(format: :rss)

        expect(response.body).to include(category.name)
      end
    end

    context "with Atom format" do
      it "returns Atom feed" do
        get feeds_listings_path(format: :atom)

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("application/atom+xml")
      end

      it "includes entries as entries" do
        get feeds_listings_path(format: :atom)

        expect(response.body).to include("<feed")
        expect(response.body).to include("<entry>")
      end
    end
  end

  describe "GET /feeds/categories/:id" do
    let!(:category_listings) do
      create_list(:entry, 3, :directory, site: site, category: category)
    end

    context "with RSS format" do
      it "returns RSS feed for category" do
        get feeds_category_path(category, format: :rss)

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("application/rss+xml")
      end

      it "includes only category entries" do
        other_category = create(:category, site: site, tenant: tenant, name: "Other")
        create(:entry, :directory, site: site, category: other_category, title: "Other Entry")

        get feeds_category_path(category, format: :rss)

        expect(response.body).to include(category_listings.first.title)
        expect(response.body).not_to include("Other Entry")
      end

      it "includes category name in title" do
        get feeds_category_path(category, format: :rss)

        expect(response.body).to include(category.name)
      end
    end

    context "with Atom format" do
      it "returns Atom feed for category" do
        get feeds_category_path(category, format: :atom)

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("application/atom+xml")
      end
    end

    it "returns 404 for non-existent category" do
      get feeds_category_path(id: 99999, format: :rss)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "feed autodiscovery" do
    it "includes RSS autodiscovery link in layout" do
      get root_path

      expect(response.body).to include('application/rss+xml')
      expect(response.body).to include('feeds/content')
    end

    it "includes Atom autodiscovery link in layout" do
      get root_path

      expect(response.body).to include('application/atom+xml')
    end
  end
end
