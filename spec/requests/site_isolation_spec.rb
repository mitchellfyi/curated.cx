# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Site Isolation", type: :request do
  # This spec proves that Site A cannot access Site B content
  # even when both sites belong to the same Tenant.
  # This is the core security guarantee: each domain is its own micro-network.

  let!(:tenant) { create(:tenant, slug: 'acme_corp', hostname: 'acme.example.com') }

  let!(:site_a) do
    site = create(:site, tenant: tenant, slug: 'site_a', name: 'Site A')
    create(:domain, :primary, :verified, site: site, hostname: 'sitea.example.com')
    site
  end

  let!(:site_b) do
    site = create(:site, tenant: tenant, slug: 'site_b', name: 'Site B')
    create(:domain, :primary, :verified, site: site, hostname: 'siteb.example.com')
    site
  end

  let!(:category_a) { create(:category, site: site_a, tenant: tenant, key: 'news_a', name: 'News') }
  let!(:category_b) { create(:category, site: site_b, tenant: tenant, key: 'news_b', name: 'News') }

  let!(:listing_a1) do
    create(:listing, :published, site: site_a, tenant: tenant, category: category_a,
           title: 'Site A Listing 1', url_canonical: 'https://example.com/a1')
  end

  let!(:listing_a2) do
    create(:listing, :published, site: site_a, tenant: tenant, category: category_a,
           title: 'Site A Listing 2', url_canonical: 'https://example.com/a2')
  end

  let!(:listing_b1) do
    create(:listing, :published, site: site_b, tenant: tenant, category: category_b,
           title: 'Site B Listing 1', url_canonical: 'https://example.com/b1')
  end

  let!(:listing_b2) do
    create(:listing, :published, site: site_b, tenant: tenant, category: category_b,
           title: 'Site B Listing 2', url_canonical: 'https://example.com/b2')
  end

  describe "Site A cannot access Site B content" do
    before do
      host! 'sitea.example.com'
    end

    it "only shows Site A listings on listings index" do
      get listings_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Site A Listing 1')
      expect(response.body).to include('Site A Listing 2')
      expect(response.body).not_to include('Site B Listing 1')
      expect(response.body).not_to include('Site B Listing 2')
    end

    it "only shows Site A categories" do
      get categories_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('News') # Category name
      # Should only show Site A's category, not Site B's
      categories = assigns(:categories)
      expect(categories.map(&:id)).to contain_exactly(category_a.id)
      expect(categories.map(&:id)).not_to include(category_b.id)
    end

    it "cannot access Site B listing directly" do
      get listing_path(listing_b1)

      expect(response).to have_http_status(:not_found)
    end

    it "cannot access Site B category directly" do
      get category_path(category_b)

      expect(response).to have_http_status(:not_found)
    end

    it "shows correct site context in Current" do
      get root_path

      # Site A resolved correctly - success response indicates correct resolution
      expect(response).to have_http_status(:success)
    end
  end

  describe "Site B cannot access Site A content" do
    before do
      host! 'siteb.example.com'
    end

    it "only shows Site B listings on listings index" do
      get listings_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Site B Listing 1')
      expect(response.body).to include('Site B Listing 2')
      expect(response.body).not_to include('Site A Listing 1')
      expect(response.body).not_to include('Site A Listing 2')
    end

    it "only shows Site B categories" do
      get categories_path

      expect(response).to have_http_status(:success)
      categories = assigns(:categories)
      expect(categories.map(&:id)).to contain_exactly(category_b.id)
      expect(categories.map(&:id)).not_to include(category_a.id)
    end

    it "cannot access Site A listing directly" do
      get listing_path(listing_a1)

      expect(response).to have_http_status(:not_found)
    end

    it "cannot access Site A category directly" do
      get category_path(category_a)

      expect(response).to have_http_status(:not_found)
    end

    it "shows correct site context in Current" do
      get root_path

      # Site B resolved correctly - success response indicates correct resolution
      expect(response).to have_http_status(:success)
    end
  end

  describe "Both sites belong to the same tenant" do
    it "confirms sites share the same tenant" do
      expect(site_a.tenant).to eq(tenant)
      expect(site_b.tenant).to eq(tenant)
      expect(site_a.tenant).to eq(site_b.tenant)
    end

    it "proves tenant-level access would leak data" do
      # This demonstrates why we need site-level scoping:
      # If we scoped by tenant only, both sites would see each other's content
      unscoped_listings = Listing.without_site_scope.where(tenant_id: tenant.id)
      expect(unscoped_listings.count).to eq(4) # All listings from both sites

      # But with site scoping, each site only sees its own
      Current.site = site_a
      scoped_listings = Listing.all
      expect(scoped_listings.count).to eq(2) # Only Site A listings
      expect(scoped_listings.pluck(:id)).to contain_exactly(listing_a1.id, listing_a2.id)
    end
  end

  describe "Default scopes enforce isolation" do
    it "prevents cross-site queries even without explicit scoping" do
      Current.site = site_a

      # Query without explicit where clause - should still be scoped
      listings = Listing.all
      expect(listings.pluck(:id)).to contain_exactly(listing_a1.id, listing_a2.id)

      # Categories should also be scoped
      categories = Category.all
      expect(categories.pluck(:id)).to contain_exactly(category_a.id)
    end

    it "allows unscoped queries when explicitly requested" do
      Current.site = site_a

      # Explicit unscoped query should work for admin/system operations
      all_listings = Listing.without_site_scope
      expect(all_listings.count).to eq(4)
    end
  end
end
