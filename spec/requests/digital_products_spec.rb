# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Digital Products", type: :request do
  let(:tenant) { create(:tenant, :enabled) }

  # Use Current.site which is set by setup_tenant_context
  def site
    Current.site
  end

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
  end

  describe "GET /products" do
    context "when digital_products feature is enabled" do
      before do
        Current.site.update!(config: Current.site.config.merge("digital_products" => { "enabled" => true }))
      end

      context "with published products" do
        let!(:published_product1) { create(:digital_product, :published, site: site, title: "Product A", created_at: 1.day.ago) }
        let!(:published_product2) { create(:digital_product, :published, site: site, title: "Product B", created_at: 1.hour.ago) }
        let!(:draft_product) { create(:digital_product, :draft, site: site, title: "Draft Product") }
        let!(:archived_product) { create(:digital_product, :archived, site: site, title: "Archived Product") }

        it "returns http success" do
          get products_path
          expect(response).to have_http_status(:success)
        end

        it "displays only published products" do
          get products_path
          expect(response.body).to include("Product A")
          expect(response.body).to include("Product B")
          expect(response.body).not_to include("Draft Product")
          expect(response.body).not_to include("Archived Product")
        end

        it "orders products by most recent first" do
          get products_path
          expect(response.body.index("Product B")).to be < response.body.index("Product A")
        end

        it "renders the index template" do
          get products_path
          expect(response).to render_template(:index)
        end
      end

      context "without products" do
        it "returns http success" do
          get products_path
          expect(response).to have_http_status(:success)
        end
      end
    end

    context "when digital_products feature is disabled" do
      before do
        Current.site.update!(config: Current.site.config.merge("digital_products" => { "enabled" => false }))
      end

      it "redirects to root path" do
        get products_path
        expect(response).to redirect_to(root_path)
      end

      it "shows alert message" do
        get products_path
        follow_redirect!
        expect(response.body).to include(I18n.t("digital_products.disabled"))
      end
    end

    context "when digital_products feature is not configured" do
      it "redirects to root path (default is disabled)" do
        get products_path
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /products/:slug" do
    context "when digital_products feature is enabled" do
      let!(:product) { create(:digital_product, :published, site: site, title: "My Product", price_cents: 1999) }

      before do
        Current.site.update!(config: Current.site.config.merge("digital_products" => { "enabled" => true }))
      end

      it "returns http success" do
        get product_path(product.slug)
        expect(response).to have_http_status(:success)
      end

      it "displays the product details" do
        get product_path(product.slug)
        expect(response.body).to include("My Product")
        expect(response.body).to include("$19.99")
      end

      it "renders the show template" do
        get product_path(product.slug)
        expect(response).to render_template(:show)
      end

      context "with draft product" do
        let!(:draft_product) { create(:digital_product, :draft, site: site) }

        it "returns 404" do
          get product_path(draft_product.slug)
          expect(response).to have_http_status(:not_found)
        end
      end

      context "with non-existent slug" do
        it "returns 404" do
          get product_path("non-existent-product")
          expect(response).to have_http_status(:not_found)
        end
      end

      context "with free product" do
        let!(:free_product) { create(:digital_product, :published, :free, site: site, title: "Free Product") }

        it "displays free label" do
          get product_path(free_product.slug)
          expect(response.body).to include("Free")
        end
      end
    end

    context "when digital_products feature is disabled" do
      let!(:product) { create(:digital_product, :published, site: site, title: "My Product") }

      before do
        Current.site.update!(config: Current.site.config.merge("digital_products" => { "enabled" => false }))
      end

      it "redirects to root path" do
        get product_path(product.slug)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "site isolation" do
    before do
      Current.site.update!(config: Current.site.config.merge("digital_products" => { "enabled" => true }))
    end

    let!(:product) { create(:digital_product, :published, site: site) }

    # Create another site within the same tenant (multi-site scenario)
    let!(:other_site) do
      Site.create!(
        tenant: tenant,
        name: "Other Site",
        slug: "other_site",
        config: { "digital_products" => { "enabled" => true } }
      )
    end
    let!(:other_product) { create(:digital_product, :published, site: other_site) }

    it "only shows products for the current site" do
      get products_path
      expect(response.body).to include(product.title)
      expect(response.body).not_to include(other_product.title)
    end

    it "cannot access product from another site by slug" do
      get product_path(other_product.slug)
      expect(response).to have_http_status(:not_found)
    end
  end
end
