# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Product Checkouts", type: :request do
  let(:tenant) { create(:tenant, :enabled) }

  def site
    Current.site
  end

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
    Current.site.update!(config: Current.site.config.merge("digital_products" => { "enabled" => true }))
    Stripe.api_key = "sk_test_fake_key"
  end

  describe "POST /products/:product_id/checkout" do
    context "with free product" do
      let!(:product) { create(:digital_product, :published, :free, site: site) }

      it "creates a purchase record" do
        expect {
          post product_checkout_path(product.slug), params: { email: "buyer@example.com" }
        }.to change(Purchase, :count).by(1)
      end

      it "creates a download token" do
        expect {
          post product_checkout_path(product.slug), params: { email: "buyer@example.com" }
        }.to change(DownloadToken, :count).by(1)
      end

      it "redirects to success page" do
        post product_checkout_path(product.slug), params: { email: "buyer@example.com" }
        expect(response).to redirect_to(success_product_checkout_path(product.slug))
      end

      it "enqueues a receipt email" do
        expect {
          post product_checkout_path(product.slug), params: { email: "buyer@example.com" }
        }.to have_enqueued_mail(DigitalProductMailer, :purchase_receipt)
      end
    end

    context "with paid product" do
      let!(:product) { create(:digital_product, :published, site: site, price_cents: 1999) }
      let(:mock_session) do
        double("Stripe::Checkout::Session",
          id: "cs_test_123",
          url: "https://checkout.stripe.com/test")
      end

      before do
        allow(Stripe::Checkout::Session).to receive(:create).and_return(mock_session)
      end

      it "redirects to Stripe checkout" do
        post product_checkout_path(product.slug), params: { email: "buyer@example.com" }
        expect(response).to redirect_to("https://checkout.stripe.com/test")
      end

      it "does not create a purchase record" do
        expect {
          post product_checkout_path(product.slug), params: { email: "buyer@example.com" }
        }.not_to change(Purchase, :count)
      end
    end

    context "with missing email" do
      let!(:product) { create(:digital_product, :published, site: site) }

      it "redirects back to product" do
        post product_checkout_path(product.slug), params: { email: "" }
        expect(response).to redirect_to(product_path(product.slug))
      end
    end

    context "when feature is disabled" do
      let!(:product) { create(:digital_product, :published, site: site) }

      before do
        Current.site.update!(config: Current.site.config.merge("digital_products" => { "enabled" => false }))
      end

      it "redirects to root path" do
        post product_checkout_path(product.slug), params: { email: "buyer@example.com" }
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /products/:product_id/checkout/success" do
    let!(:product) { create(:digital_product, :published, site: site) }

    it "returns success" do
      get success_product_checkout_path(product.slug)
      expect(response).to have_http_status(:success)
    end

    it "displays success message" do
      get success_product_checkout_path(product.slug)
      expect(response.body).to include(I18n.t("digital_products.checkout.success_message"))
    end
  end

  describe "GET /products/:product_id/checkout/cancel" do
    let!(:product) { create(:digital_product, :published, site: site) }

    it "returns success" do
      get cancel_product_checkout_path(product.slug)
      expect(response).to have_http_status(:success)
    end

    it "displays cancel message" do
      get cancel_product_checkout_path(product.slug)
      expect(response.body).to include(I18n.t("digital_products.checkout.cancel_message"))
    end
  end
end
