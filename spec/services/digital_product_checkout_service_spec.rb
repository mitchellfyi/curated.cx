# frozen_string_literal: true

require "rails_helper"

RSpec.describe DigitalProductCheckoutService do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { create(:site, tenant: tenant) }
  let(:digital_product) { create(:digital_product, :published, site: site, price_cents: 1999) }
  let(:email) { "customer@example.com" }

  before do
    Current.tenant = tenant
    Current.site = site
    Stripe.api_key = "sk_test_fake_key"
  end

  describe "#initialize" do
    it "accepts valid digital product and email" do
      expect {
        described_class.new(digital_product, email: email)
      }.not_to raise_error
    end

    context "when Stripe is not configured" do
      before { Stripe.api_key = nil }

      it "raises StripeNotConfiguredError" do
        expect {
          described_class.new(digital_product, email: email)
        }.to raise_error(DigitalProductCheckoutService::StripeNotConfiguredError)
      end
    end
  end

  describe "#create_session" do
    let(:service) { described_class.new(digital_product, email: email) }
    let(:mock_session) do
      double("Stripe::Checkout::Session",
        id: "cs_test_123",
        url: "https://checkout.stripe.com/test")
    end

    before do
      allow(Stripe::Checkout::Session).to receive(:create).and_return(mock_session)
    end

    it "creates a Stripe checkout session" do
      expect(Stripe::Checkout::Session).to receive(:create).with(hash_including(
        mode: "payment",
        customer_email: email
      ))

      service.create_session(
        success_url: "https://example.com/success",
        cancel_url: "https://example.com/cancel"
      )
    end

    it "includes correct metadata" do
      expect(Stripe::Checkout::Session).to receive(:create).with(hash_including(
        metadata: hash_including(
          checkout_type: "digital_product",
          digital_product_id: digital_product.id.to_s,
          site_id: site.id.to_s,
          purchaser_email: email
        )
      ))

      service.create_session(
        success_url: "https://example.com/success",
        cancel_url: "https://example.com/cancel"
      )
    end

    it "includes correct line item with product details" do
      expect(Stripe::Checkout::Session).to receive(:create).with(hash_including(
        line_items: [
          hash_including(
            price_data: hash_including(
              currency: "usd",
              product_data: hash_including(
                name: digital_product.title
              ),
              unit_amount: digital_product.price_cents
            ),
            quantity: 1
          )
        ]
      ))

      service.create_session(
        success_url: "https://example.com/success",
        cancel_url: "https://example.com/cancel"
      )
    end

    it "returns the session" do
      result = service.create_session(
        success_url: "https://example.com/success",
        cancel_url: "https://example.com/cancel"
      )

      expect(result).to eq(mock_session)
    end

    context "when product is not published" do
      let(:digital_product) { create(:digital_product, :draft, site: site) }

      it "raises ProductNotPublishedError" do
        expect {
          service.create_session(
            success_url: "https://example.com/success",
            cancel_url: "https://example.com/cancel"
          )
        }.to raise_error(DigitalProductCheckoutService::ProductNotPublishedError)
      end
    end

    context "when product has no description" do
      let(:digital_product) { create(:digital_product, :published, site: site, description: nil) }

      it "uses default description" do
        expect(Stripe::Checkout::Session).to receive(:create).with(hash_including(
          line_items: [
            hash_including(
              price_data: hash_including(
                product_data: hash_including(
                  description: "Digital download"
                )
              )
            )
          ]
        ))

        service.create_session(
          success_url: "https://example.com/success",
          cancel_url: "https://example.com/cancel"
        )
      end
    end
  end

  describe "#purchase_free!" do
    let(:free_product) { create(:digital_product, :published, :free, site: site) }
    let(:service) { described_class.new(free_product, email: email) }

    it "creates a purchase record" do
      expect {
        service.purchase_free!
      }.to change(Purchase, :count).by(1)
    end

    it "returns the created purchase" do
      result = service.purchase_free!

      expect(result).to be_a(Purchase)
      expect(result).to be_persisted
    end

    it "creates purchase with correct attributes" do
      purchase = service.purchase_free!

      expect(purchase.site).to eq(site)
      expect(purchase.digital_product).to eq(free_product)
      expect(purchase.email).to eq(email)
      expect(purchase.amount_cents).to eq(0)
      expect(purchase.source).to eq("checkout")
    end

    it "creates a download token" do
      expect {
        service.purchase_free!
      }.to change(DownloadToken, :count).by(1)
    end

    it "associates download token with purchase" do
      purchase = service.purchase_free!

      expect(purchase.download_tokens).to be_present
      expect(purchase.download_tokens.first).to be_valid_for_download
    end

    context "when product is not published" do
      let(:free_product) { create(:digital_product, :draft, :free, site: site) }

      it "raises ProductNotPublishedError" do
        expect {
          service.purchase_free!
        }.to raise_error(DigitalProductCheckoutService::ProductNotPublishedError)
      end
    end

    context "when product is not free" do
      let(:service) { described_class.new(digital_product, email: email) }

      it "raises ArgumentError" do
        expect {
          service.purchase_free!
        }.to raise_error(ArgumentError, "Product is not free")
      end
    end
  end

  describe "attributes" do
    let(:service) { described_class.new(digital_product, email: email) }

    it "exposes digital_product" do
      expect(service.digital_product).to eq(digital_product)
    end

    it "exposes email" do
      expect(service.email).to eq(email)
    end
  end
end
