# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Search", type: :request do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:source) { create(:source, site: site) }
  let(:category) { create(:category, tenant: tenant) }

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
  end

  describe "GET /search" do
    it "returns http success" do
      get search_path

      expect(response).to have_http_status(:success)
    end

    it "renders the index template" do
      get search_path

      expect(response).to render_template(:index)
    end

    context "without query" do
      it "shows empty state" do
        get search_path

        expect(assigns(:query)).to eq("")
        expect(assigns(:total_count)).to eq(0)
      end
    end

    context "with short query" do
      it "does not perform search for queries under 2 characters" do
        get search_path, params: { q: "a" }

        expect(assigns(:total_count)).to eq(0)
      end
    end

    context "with valid query" do
      let!(:matching_item) do
        item = create(:content_item, :published, site: site, source: source)
        item.update_columns(title: "Introduction to Ruby Programming")
        item
      end

      let!(:non_matching_item) do
        item = create(:content_item, :published, site: site, source: source)
        item.update_columns(title: "Python Tutorial")
        item
      end

      it "returns matching content items" do
        get search_path, params: { q: "Ruby" }

        expect(assigns(:content_items)).to include(matching_item)
        expect(assigns(:content_items)).not_to include(non_matching_item)
      end

      it "assigns total count" do
        get search_path, params: { q: "Ruby" }

        expect(assigns(:total_count)).to be >= 1
      end
    end

    context "searching listings" do
      let!(:matching_listing) do
        listing = create(:listing, site: site, category: category)
        listing.update_columns(title: "Ruby Developer Tool", published_at: Time.current)
        listing
      end

      let!(:non_matching_listing) do
        listing = create(:listing, site: site, category: category)
        listing.update_columns(title: "Python IDE", published_at: Time.current)
        listing
      end

      it "returns matching listings" do
        get search_path, params: { q: "Ruby" }

        expect(assigns(:listings)).to include(matching_listing)
        expect(assigns(:listings)).not_to include(non_matching_listing)
      end
    end

    context "type filtering" do
      let!(:content_item) do
        item = create(:content_item, :published, site: site, source: source)
        item.update_columns(title: "Ruby Content")
        item
      end

      let!(:listing) do
        listing = create(:listing, site: site, category: category)
        listing.update_columns(title: "Ruby Listing", published_at: Time.current)
        listing
      end

      it "filters to content only" do
        get search_path, params: { q: "Ruby", type: "content" }

        expect(assigns(:content_items)).to include(content_item)
        expect(assigns(:listings)).to be_empty
      end

      it "filters to listings only" do
        get search_path, params: { q: "Ruby", type: "listings" }

        expect(assigns(:content_items)).to be_empty
        expect(assigns(:listings)).to include(listing)
      end

      it "returns both when no type filter" do
        get search_path, params: { q: "Ruby" }

        expect(assigns(:content_items)).to include(content_item)
        expect(assigns(:listings)).to include(listing)
      end
    end

    context "site isolation" do
      let!(:other_item) do
        ActsAsTenant.without_tenant do
          other_tenant = create(:tenant, :enabled)
          other_site = other_tenant.sites.first
          other_source = create(:source, site: other_site, tenant: other_tenant)
          item = create(:content_item, :published, site: other_site, source: other_source)
          item.update_columns(title: "Ruby from Other Site")
          item
        end
      end

      let!(:our_item) do
        item = create(:content_item, :published, site: site, source: source)
        item.update_columns(title: "Ruby from Our Site")
        item
      end

      it "only shows content from current site" do
        get search_path, params: { q: "Ruby" }

        expect(assigns(:content_items)).to include(our_item)
        expect(assigns(:content_items)).not_to include(other_item)
      end
    end

    context "meta tags" do
      it "sets noindex for search pages" do
        get search_path, params: { q: "test" }

        expect(response.body).to include('name="robots"')
      end
    end

    context "when tenant requires login" do
      let(:private_tenant) { create(:tenant, :private_access) }

      before do
        host! private_tenant.hostname
        setup_tenant_context(private_tenant)
      end

      context "when user is not signed in" do
        it "redirects to sign in" do
          get search_path

          expect(response).to redirect_to(new_user_session_path)
        end
      end

      context "when user is signed in" do
        let(:user) { create(:user) }

        before do
          sign_in user
          user.add_role(:viewer, private_tenant)
        end

        it "returns http success" do
          get search_path

          expect(response).to have_http_status(:success)
        end
      end
    end
  end

  describe "authorization" do
    it "uses SearchPolicy for index action" do
      expect_any_instance_of(SearchPolicy).to receive(:index?).and_return(true)

      get search_path
    end
  end
end
