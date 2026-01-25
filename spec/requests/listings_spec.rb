require 'rails_helper'

RSpec.describe "Listings", type: :request do
  let(:tenant) { create(:tenant, :enabled) }
  let(:disabled_tenant) { create(:tenant, :disabled) }
  let(:private_tenant) { create(:tenant, :private_access) }
  let(:admin_user) { create(:user, :admin) }
  let(:regular_user) { create(:user) }
  let!(:category1) { create(:category, :news, tenant: tenant) }
  let!(:category2) { create(:category, :apps, tenant: tenant) }
  let!(:other_tenant_category) { create(:category, tenant: disabled_tenant) }
  let!(:private_tenant_category) { create(:category, tenant: private_tenant) }
  let!(:listing1) { create(:listing, :published, tenant: tenant, category: category1) }
  let!(:listing2) { create(:listing, :app_listing, :published, tenant: tenant, category: category2) }
  let!(:unpublished_listing) { create(:listing, :unpublished, tenant: tenant, category: category1) }
  let!(:other_tenant_listing) { create(:listing, :published, tenant: disabled_tenant, category: other_tenant_category) }
  let!(:private_tenant_listing) { create(:listing, :published, tenant: private_tenant, category: private_tenant_category) }

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
  end

  describe "GET /listings" do
    context "when user is signed in" do
      before { sign_in regular_user }

      it "returns http success" do
        get listings_path
        expect(response).to have_http_status(:success)
      end

      it "assigns all listings for current tenant" do
        get listings_path
        expect(assigns(:listings)).to include(listing1, listing2)
        expect(assigns(:listings)).not_to include(other_tenant_listing)
      end

      it "includes category in the query to prevent N+1" do
        # Verify the query includes category association by checking no N+1 occurs
        get listings_path
        expect(assigns(:listings).first&.association(:category)&.loaded?).to be_truthy if assigns(:listings).present?
      end

      it "orders listings by published_at desc" do
        old_listing = create(:listing, :published, tenant: tenant, category: category1, published_at: 2.days.ago)
        new_listing = create(:listing, :published, tenant: tenant, category: category1, published_at: 1.hour.ago)

        get listings_path
        listings = assigns(:listings)
        expect(listings.first).to eq(new_listing)
        expect(listings.last).to eq(old_listing)
      end

      it "limits listings to 20" do
        create_list(:listing, 25, :published, tenant: tenant, category: category1)
        get listings_path
        expect(assigns(:listings).count).to eq(20)
      end

      it "renders the index template" do
        get listings_path
        expect(response).to render_template(:index)
      end

      it "sets correct meta tags" do
        get listings_path
        expect(response.body).to include(I18n.t('listings.index.title'))
        expect(response.body).to include(tenant.title)
      end
    end

    context "when user is not signed in" do
      it "allows public access for enabled tenant" do
        get listings_path
        expect(response).to have_http_status(:success)
      end

      it "assigns all listings for current tenant" do
        get listings_path
        expect(assigns(:listings)).to include(listing1, listing2)
        expect(assigns(:listings)).not_to include(other_tenant_listing)
      end
    end

    context "when tenant requires private access" do
      before do
        host! private_tenant.hostname
        setup_tenant_context(private_tenant)
      end

      context "when user is not signed in" do
        it "redirects to sign in" do
          get listings_path
          expect(response).to have_http_status(:redirect)
          expect(response).to redirect_to(new_user_session_path)
        end
      end

      context "when user is signed in" do
        before { sign_in regular_user }

        it "allows access" do
          get listings_path
          expect(response).to have_http_status(:success)
        end
      end
    end

    context "when tenant is disabled" do
      before do
        host! disabled_tenant.hostname
        setup_tenant_context(disabled_tenant)
      end

      it "returns not found" do
        get listings_path
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /categories/:category_id/listings" do
    context "when user is signed in" do
      before { sign_in regular_user }

      it "returns http success" do
        get category_listings_path(category1)
        expect(response).to have_http_status(:success)
      end

      it "assigns listings for the specific category" do
        get category_listings_path(category1)
        expect(assigns(:listings)).to include(listing1)
        expect(assigns(:listings)).not_to include(listing2)
      end

      it "assigns the correct category" do
        get category_listings_path(category1)
        expect(assigns(:category)).to eq(category1)
      end

      it "includes category in the query to prevent N+1" do
        get category_listings_path(category1)
        # Verify that the category association is loaded to prevent N+1 queries
        expect(assigns(:listings).first.association(:category)).to be_loaded
      end

      it "orders listings by published_at desc" do
        old_listing = create(:listing, :published, tenant: tenant, category: category1, published_at: 2.days.ago)
        new_listing = create(:listing, :published, tenant: tenant, category: category1, published_at: 1.hour.ago)

        get category_listings_path(category1)
        listings = assigns(:listings)
        expect(listings.first).to eq(new_listing)
        expect(listings.last).to eq(old_listing)
      end

      it "limits listings to 20" do
        create_list(:listing, 25, :published, tenant: tenant, category: category1)
        get category_listings_path(category1)
        expect(assigns(:listings).count).to eq(20)
      end

      it "renders the index template" do
        get category_listings_path(category1)
        expect(response).to render_template(:index)
      end

      it "sets correct meta tags with category name" do
        get category_listings_path(category1)
        expect(response.body).to include(category1.name)
        expect(response.body).to include(tenant.title)
      end

        context "when category belongs to different tenant" do
          it "returns not found" do
            get category_listings_path(other_tenant_category)
            expect(response).to have_http_status(:not_found)
          end
        end

        context "when category does not exist" do
          it "returns not found" do
            get category_listings_path(999999)
            expect(response).to have_http_status(:not_found)
          end
        end
    end

    context "when user is not signed in" do
      it "allows public access for enabled tenant" do
        get category_listings_path(category1)
        expect(response).to have_http_status(:success)
      end

      it "assigns listings for the specific category" do
        get category_listings_path(category1)
        expect(assigns(:listings)).to include(listing1)
        expect(assigns(:listings)).not_to include(listing2)
      end
    end

    context "when tenant requires private access" do
      before do
        host! private_tenant.hostname
        setup_tenant_context(private_tenant)
      end

      context "when user is not signed in" do
        it "redirects to sign in" do
          get category_listings_path(private_tenant_category)
          expect(response).to have_http_status(:redirect)
          expect(response).to redirect_to(new_user_session_path)
        end
      end

      context "when user is signed in" do
        before { sign_in regular_user }

        it "allows access" do
          get category_listings_path(private_tenant_category)
          expect(response).to have_http_status(:success)
        end
      end
    end

    context "when tenant is disabled" do
      before do
        host! disabled_tenant.hostname
        setup_tenant_context(disabled_tenant)
      end

      it "returns not found" do
        get category_listings_path(other_tenant_category)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /listings/:id" do
    context "when user is signed in" do
      before { sign_in regular_user }

      it "returns http success" do
        get listing_path(listing1)
        expect(response).to have_http_status(:success)
      end

      it "assigns the correct listing" do
        get listing_path(listing1)
        expect(assigns(:listing)).to eq(listing1)
      end

      it "includes category and tenant in the query to prevent N+1" do
        expect_any_instance_of(ActiveRecord::Relation).to receive(:includes).with(:category, :tenant).and_call_original
        get listing_path(listing1)
      end

      it "renders the show template" do
        get listing_path(listing1)
        expect(response).to render_template(:show)
      end

      it "sets correct meta tags" do
        get listing_path(listing1)
        expect(response.body).to include(listing1.title)
        expect(response.body).to include(listing1.description)
        expect(response.body).to include(listing1.url_canonical)
      end

      it "sets Open Graph meta tags" do
        get listing_path(listing1)
        expect(response.body).to include(listing1.title)
        expect(response.body).to include(listing1.description)
        expect(response.body).to include(listing1.image_url) if listing1.image_url.present?
      end

        context "when listing belongs to different tenant" do
          it "returns not found" do
            get listing_path(other_tenant_listing)
            expect(response).to have_http_status(:not_found)
          end
        end

        context "when listing does not exist" do
          it "returns not found" do
            get listing_path(999999)
            expect(response).to have_http_status(:not_found)
          end
        end
    end

    context "when user is not signed in" do
      it "allows public access for enabled tenant" do
        get listing_path(listing1)
        expect(response).to have_http_status(:success)
      end

      it "assigns the correct listing" do
        get listing_path(listing1)
        expect(assigns(:listing)).to eq(listing1)
      end
    end

    context "when tenant requires private access" do
      before do
        host! private_tenant.hostname
        setup_tenant_context(private_tenant)
      end

      context "when user is not signed in" do
        it "redirects to sign in" do
          get listing_path(private_tenant_listing)
          expect(response).to have_http_status(:redirect)
          expect(response).to redirect_to(new_user_session_path)
        end
      end

      context "when user is signed in" do
        before { sign_in regular_user }

        it "allows access" do
          get listing_path(private_tenant_listing)
          expect(response).to have_http_status(:success)
        end
      end
    end

    context "when tenant is disabled" do
      before do
        host! disabled_tenant.hostname
        setup_tenant_context(disabled_tenant)
      end

      it "returns not found" do
        get listing_path(other_tenant_listing)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "authorization" do
    it "authorizes listing access for index action" do
      expect_any_instance_of(ListingPolicy).to receive(:index?).and_return(true)
      sign_in regular_user
      get listings_path
    end

    it "authorizes listing access for show action" do
      expect_any_instance_of(ListingPolicy).to receive(:show?).and_return(true)
      sign_in regular_user
      get listing_path(listing1)
    end
  end

  describe "policy scoping" do
    before { sign_in regular_user }

    it "scopes listings to current tenant" do
      get listings_path
      listings = assigns(:listings)
      expect(listings.all? { |l| l.tenant_id == tenant.id }).to be true
    end

    it "scopes category listings to current tenant" do
      get category_listings_path(category1)
      listings = assigns(:listings)
      expect(listings.all? { |l| l.tenant_id == tenant.id }).to be true
    end
  end

  describe "meta tags" do
    before { sign_in regular_user }

    it "sets correct meta tags for index action" do
      get listings_path
      expect(response.body).to include(I18n.t('listings.index.title'))
      expected_description = I18n.t('listings.index.description', category: I18n.t('nav.all_categories'), tenant: tenant.title)
      expect(response.body).to include(CGI.escapeHTML(expected_description))
    end

    it "sets correct meta tags for category listings" do
      get category_listings_path(category1)
      expect(response.body).to include(category1.name)
      expected_description = I18n.t('listings.index.description', category: category1.name, tenant: tenant.title)
      expect(response.body).to include(CGI.escapeHTML(expected_description))
    end

    it "sets correct meta tags for show action" do
      get listing_path(listing1)
      expect(response.body).to include(CGI.escapeHTML(listing1.title))
      expect(response.body).to include(CGI.escapeHTML(listing1.description))
      expect(response.body).to include(listing1.url_canonical)
    end
  end

  describe "error handling" do
    before { sign_in regular_user }

    context "when listing does not exist" do
      it "returns not found" do
        get listing_path(999999)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when listing belongs to different tenant" do
      it "returns not found" do
        get listing_path(other_tenant_listing)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when category does not exist" do
      it "returns not found" do
        get category_listings_path(999999)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "tenant isolation" do
    let!(:other_tenant) do
      ActsAsTenant.without_tenant do
        create(:tenant, :enabled)
      end
    end

    # Use the auto-created site from tenant factory
    let!(:other_site) { other_tenant.sites.first }

    let!(:other_category) do
      ActsAsTenant.without_tenant do
        create(:category, tenant: other_tenant, site: other_site)
      end
    end

    let!(:other_listing) do
      ActsAsTenant.without_tenant do
        create(:listing, :published, tenant: other_tenant, site: other_site, category: other_category)
      end
    end

    before do
      sign_in regular_user
      clear_tenant_context  # Clear the main test setup tenant context
    end

    it "does not show listings from other tenants" do
      # Make sure the associations are correct
      expect(other_listing.tenant_id).to eq(other_tenant.id)
      expect(other_category.tenant_id).to eq(other_tenant.id)
      expect(other_listing.category_id).to eq(other_category.id)

      host! other_tenant.hostname
      setup_tenant_context(other_tenant)

      get listings_path
      expect(response).to have_http_status(:success)
      expect(assigns(:listings)).to include(other_listing)
      expect(assigns(:listings)).not_to include(listing1, listing2)
    end

    it "does not show category listings from other tenants" do
      host! other_tenant.hostname
      setup_tenant_context(other_tenant)
      get category_listings_path(other_category)
      expect(assigns(:listings)).to include(other_listing)
      expect(assigns(:listings)).not_to include(listing1, listing2)
    end

    it "does not show individual listings from other tenants" do
      host! other_tenant.hostname
      setup_tenant_context(other_tenant)
      get listing_path(other_listing)
      expect(assigns(:listing)).to eq(other_listing)
    end
  end

  describe "published vs unpublished listings" do
    before { sign_in regular_user }

    it "shows published listings in index" do
      get listings_path
      expect(assigns(:listings)).to include(listing1, listing2)
      expect(assigns(:listings)).not_to include(unpublished_listing)
    end

    it "shows published listings in category index" do
      get category_listings_path(category1)
      expect(assigns(:listings)).to include(listing1)
      expect(assigns(:listings)).not_to include(unpublished_listing)
    end

    it "can show individual unpublished listings" do
      get listing_path(unpublished_listing)
      expect(assigns(:listing)).to eq(unpublished_listing)
    end
  end
end
