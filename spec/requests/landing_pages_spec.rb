# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Landing Pages", type: :request do
  let(:tenant) { create(:tenant, :enabled, slug: "test") }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }

  before do
    Current.tenant = tenant
    Current.site = site
    host! "#{tenant.slug}.localhost"
  end

  describe "GET /p/:slug" do
    context "with a published landing page" do
      let!(:landing_page) { create(:landing_page, :full_page, site: site, tenant: tenant, slug: "summer-launch") }

      it "renders the landing page" do
        get landing_page_path(landing_page.slug)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(landing_page.headline)
      end

      it "includes the CTA" do
        get landing_page_path(landing_page.slug)

        expect(response.body).to include(landing_page.cta_text)
        expect(response.body).to include(landing_page.cta_url)
      end

      it "renders feature sections" do
        get landing_page_path(landing_page.slug)

        expect(response.body).to include("Features")
      end

      it "renders testimonial sections" do
        get landing_page_path(landing_page.slug)

        expect(response.body).to include("Testimonials")
      end

      it "renders FAQ sections" do
        get landing_page_path(landing_page.slug)

        expect(response.body).to include("FAQ")
      end

      it "sets meta tags" do
        get landing_page_path(landing_page.slug)

        expect(response.body).to include("<title>#{landing_page.title}")
      end
    end

    context "with a draft landing page" do
      let!(:landing_page) { create(:landing_page, :draft, site: site, tenant: tenant, slug: "coming-soon") }

      it "returns 403 for unauthenticated users" do
        get landing_page_path(landing_page.slug)

        expect(response).to have_http_status(:redirect)
      end

      context "when user is admin" do
        let(:admin_user) { create(:user, :admin) }

        before { sign_in admin_user }

        it "allows viewing draft pages" do
          get landing_page_path(landing_page.slug)

          expect(response).to have_http_status(:ok)
        end
      end
    end

    context "with non-existent slug" do
      it "returns 404" do
        get landing_page_path("does-not-exist")

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "LandingPage model" do
    it "validates slug format" do
      page = build(:landing_page, slug: "Invalid Slug!", site: site, tenant: tenant)
      expect(page).not_to be_valid
      expect(page.errors[:slug]).to be_present
    end

    it "validates slug uniqueness per site" do
      create(:landing_page, slug: "unique-slug", site: site, tenant: tenant)
      duplicate = build(:landing_page, slug: "unique-slug", site: site, tenant: tenant)

      expect(duplicate).not_to be_valid
    end

    it "allows same slug on different sites" do
      other_site = create(:site, tenant: tenant)
      create(:landing_page, slug: "shared-slug", site: site, tenant: tenant)
      other_page = build(:landing_page, slug: "shared-slug", site: other_site, tenant: tenant)

      expect(other_page).to be_valid
    end
  end
end
