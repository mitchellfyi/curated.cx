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
  let!(:entry1) { create(:entry, :directory, :published, tenant: tenant, category: category1) }
  let!(:entry2) { create(:entry, :directory, :app_listing, :published, tenant: tenant, category: category2) }
  let!(:unpublished_entry) { create(:entry, :directory, :unpublished, tenant: tenant, category: category1) }
  let!(:other_tenant_entry) { create(:entry, :directory, :published, tenant: disabled_tenant, category: other_tenant_category) }
  let!(:private_tenant_entry) { create(:entry, :directory, :published, tenant: private_tenant, category: private_tenant_category) }

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

      it "assigns all entries for current tenant" do
        get listings_path
        expect(assigns(:entries)).to include(entry1, entry2)
        expect(assigns(:entries)).not_to include(other_tenant_entry)
      end

      it "includes category in the query to prevent N+1" do
        # Verify the query includes category association by checking no N+1 occurs
        get listings_path
        expect(assigns(:entries).first&.association(:category)&.loaded?).to be_truthy if assigns(:entries).present?
      end

      it "orders entries by published_at desc" do
        old_entry = create(:entry, :directory, :published, tenant: tenant, category: category1, published_at: 2.days.ago)
        new_entry = create(:entry, :directory, :published, tenant: tenant, category: category1, published_at: 1.hour.ago)

        get listings_path
        entries = assigns(:entries)
        expect(entries.first).to eq(new_entry)
        expect(entries.last).to eq(old_entry)
      end

      it "limits entries to 50" do
        create_list(:entry, :directory, 55, :published, tenant: tenant, category: category1)
        get listings_path
        expect(assigns(:entries).count).to eq(50)
      end

      it "renders the index template" do
        get listings_path
        expect(response).to render_template(:index)
      end

      it "sets correct meta tags" do
        get listings_path
        expect(response.body).to include(I18n.t('listings.index.title'))
        expect(response.body).to include(CGI.escapeHTML(tenant.title))
      end
    end

    context "when user is not signed in" do
      it "allows public access for enabled tenant" do
        get listings_path
        expect(response).to have_http_status(:success)
      end

      it "assigns all entries for current tenant" do
        get listings_path
        expect(assigns(:entries)).to include(entry1, entry2)
        expect(assigns(:entries)).not_to include(other_tenant_entry)
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

      it "assigns entries for the specific category" do
        get category_listings_path(category1)
        expect(assigns(:entries)).to include(entry1)
        expect(assigns(:entries)).not_to include(entry2)
      end

      it "assigns the correct category" do
        get category_listings_path(category1)
        expect(assigns(:category)).to eq(category1)
      end

      it "includes category in the query to prevent N+1" do
        get category_listings_path(category1)
        # Verify that the category association is loaded to prevent N+1 queries
        expect(assigns(:entries).first.association(:category)).to be_loaded
      end

      it "orders entries by published_at desc" do
        old_entry = create(:entry, :directory, :published, tenant: tenant, category: category1, published_at: 2.days.ago)
        new_entry = create(:entry, :directory, :published, tenant: tenant, category: category1, published_at: 1.hour.ago)

        get category_listings_path(category1)
        entries = assigns(:entries)
        expect(entries.first).to eq(new_entry)
        expect(entries.last).to eq(old_entry)
      end

      it "limits entries to 50" do
        create_list(:entry, :directory, 55, :published, tenant: tenant, category: category1)
        get category_listings_path(category1)
        expect(assigns(:entries).count).to eq(50)
      end

      it "renders the index template" do
        get category_listings_path(category1)
        expect(response).to render_template(:index)
      end

      it "sets correct meta tags with category name" do
        get category_listings_path(category1)
        expect(response.body).to include(CGI.escapeHTML(category1.name))
        expect(response.body).to include(CGI.escapeHTML(tenant.title))
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

      it "assigns entries for the specific category" do
        get category_listings_path(category1)
        expect(assigns(:entries)).to include(entry1)
        expect(assigns(:entries)).not_to include(entry2)
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
        get listing_path(entry1)
        expect(response).to have_http_status(:success)
      end

      it "assigns the correct entry" do
        get listing_path(entry1)
        expect(assigns(:entry)).to eq(entry1)
      end

      it "includes category and tenant in the query to prevent N+1" do
        expect_any_instance_of(ActiveRecord::Relation).to receive(:includes).with(:category, :tenant).and_call_original
        get listing_path(entry1)
      end

      it "renders the show template" do
        get listing_path(entry1)
        expect(response).to render_template(:show)
      end

      it "sets correct meta tags" do
        get listing_path(entry1)
        expect(response.body).to include(entry1.title)
        expect(response.body).to include(entry1.description)
        expect(response.body).to include(entry1.url_canonical)
      end

      it "sets Open Graph meta tags" do
        get listing_path(entry1)
        expect(response.body).to include(entry1.title)
        expect(response.body).to include(entry1.description)
        expect(response.body).to include(entry1.image_url) if entry1.image_url.present?
      end

        context "when entry belongs to different tenant" do
          it "returns not found" do
            get listing_path(other_tenant_entry)
            expect(response).to have_http_status(:not_found)
          end
        end

        context "when entry does not exist" do
          it "returns not found" do
            get listing_path(999999)
            expect(response).to have_http_status(:not_found)
          end
        end
    end

    context "when user is not signed in" do
      it "allows public access for enabled tenant" do
        get listing_path(entry1)
        expect(response).to have_http_status(:success)
      end

      it "assigns the correct entry" do
        get listing_path(entry1)
        expect(assigns(:entry)).to eq(entry1)
      end
    end

    context "when tenant requires private access" do
      before do
        host! private_tenant.hostname
        setup_tenant_context(private_tenant)
      end

      context "when user is not signed in" do
        it "redirects to sign in" do
          get listing_path(private_tenant_entry)
          expect(response).to have_http_status(:redirect)
          expect(response).to redirect_to(new_user_session_path)
        end
      end

      context "when user is signed in" do
        before { sign_in regular_user }

        it "allows access" do
          get listing_path(private_tenant_entry)
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
        get listing_path(other_tenant_entry)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "authorization" do
    it "authorizes entry access for index action" do
      expect_any_instance_of(EntryPolicy).to receive(:index?).and_return(true)
      sign_in regular_user
      get listings_path
    end

    it "authorizes entry access for show action" do
      expect_any_instance_of(EntryPolicy).to receive(:show?).and_return(true)
      sign_in regular_user
      get listing_path(entry1)
    end
  end

  describe "policy scoping" do
    before { sign_in regular_user }

    it "scopes entries to current tenant" do
      get listings_path
      entries = assigns(:entries)
      expect(entries.all? { |l| l.tenant_id == tenant.id }).to be true
    end

    it "scopes category entries to current tenant" do
      get category_listings_path(category1)
      entries = assigns(:entries)
      expect(entries.all? { |l| l.tenant_id == tenant.id }).to be true
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

    it "sets correct meta tags for category entries" do
      get category_listings_path(category1)
      expect(response.body).to include(category1.name)
      expected_description = I18n.t('listings.index.description', category: category1.name, tenant: tenant.title)
      expect(response.body).to include(CGI.escapeHTML(expected_description))
    end

    it "sets correct meta tags for show action" do
      get listing_path(entry1)
      expect(response.body).to include(CGI.escapeHTML(entry1.title))
      expect(response.body).to include(CGI.escapeHTML(entry1.description))
      expect(response.body).to include(entry1.url_canonical)
    end
  end

  describe "error handling" do
    before { sign_in regular_user }

    context "when entry does not exist" do
      it "returns not found" do
        get listing_path(999999)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when entry belongs to different tenant" do
      it "returns not found" do
        get listing_path(other_tenant_entry)
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

    let!(:other_entry) do
      ActsAsTenant.without_tenant do
        create(:entry, :directory, :published, tenant: other_tenant, site: other_site, category: other_category)
      end
    end

    before do
      sign_in regular_user
      clear_tenant_context  # Clear the main test setup tenant context
    end

    it "does not show entries from other tenants" do
      # Make sure the associations are correct
      expect(other_entry.tenant_id).to eq(other_tenant.id)
      expect(other_category.tenant_id).to eq(other_tenant.id)
      expect(other_entry.category_id).to eq(other_category.id)

      host! other_tenant.hostname
      setup_tenant_context(other_tenant)

      get listings_path
      expect(response).to have_http_status(:success)
      expect(assigns(:entries)).to include(other_entry)
      expect(assigns(:entries)).not_to include(entry1, entry2)
    end

    it "does not show category entries from other tenants" do
      host! other_tenant.hostname
      setup_tenant_context(other_tenant)
      get category_listings_path(other_category)
      expect(assigns(:entries)).to include(other_entry)
      expect(assigns(:entries)).not_to include(entry1, entry2)
    end

    it "does not show individual entries from other tenants" do
      host! other_tenant.hostname
      setup_tenant_context(other_tenant)
      get listing_path(other_entry)
      expect(assigns(:entry)).to eq(other_entry)
    end
  end

  describe "published vs unpublished entries" do
    before { sign_in regular_user }

    it "shows published entries in index" do
      get listings_path
      expect(assigns(:entries)).to include(entry1, entry2)
      expect(assigns(:entries)).not_to include(unpublished_entry)
    end

    it "shows published entries in category index" do
      get category_listings_path(category1)
      expect(assigns(:entries)).to include(entry1)
      expect(assigns(:entries)).not_to include(unpublished_entry)
    end

    it "can show individual unpublished entries" do
      get listing_path(unpublished_entry)
      expect(assigns(:entry)).to eq(unpublished_entry)
    end
  end
end
