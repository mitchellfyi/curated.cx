# frozen_string_literal: true

require "rails_helper"

RSpec.describe StripeCheckoutService do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { create(:site, tenant: tenant) }
  let(:category) { create(:category, tenant: tenant, site: site) }
  let(:listing) { create(:listing, :job, site: site, tenant: tenant, category: category) }

  before do
    Current.tenant = tenant
    Current.site = site
    Stripe.api_key = "sk_test_fake_key"
  end

  describe "#initialize" do
    it "accepts valid checkout types" do
      expect {
        described_class.new(listing, checkout_type: :job_post_30)
      }.not_to raise_error
    end

    it "raises error for invalid checkout types" do
      expect {
        described_class.new(listing, checkout_type: :invalid_type)
      }.to raise_error(StripeCheckoutService::InvalidCheckoutTypeError)
    end

    context "when Stripe is not configured" do
      before { Stripe.api_key = nil }

      it "raises StripeNotConfiguredError" do
        expect {
          described_class.new(listing, checkout_type: :job_post_30)
        }.to raise_error(StripeCheckoutService::StripeNotConfiguredError)
      end
    end
  end

  describe "#price_amount" do
    it "returns the correct price for job_post_30" do
      service = described_class.new(listing, checkout_type: :job_post_30)
      expect(service.price_amount).to eq(99_00)
    end

    it "returns the correct price for featured_7" do
      service = described_class.new(listing, checkout_type: :featured_7)
      expect(service.price_amount).to eq(49_00)
    end
  end

  describe "#duration_days" do
    it "returns the correct duration for job_post_60" do
      service = described_class.new(listing, checkout_type: :job_post_60)
      expect(service.duration_days).to eq(60)
    end

    it "returns the correct duration for featured_14" do
      service = described_class.new(listing, checkout_type: :featured_14)
      expect(service.duration_days).to eq(14)
    end
  end

  describe "#create_session" do
    let(:service) { described_class.new(listing, checkout_type: :job_post_30) }
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
        client_reference_id: listing.id.to_s
      ))

      service.create_session(
        success_url: "https://example.com/success",
        cancel_url: "https://example.com/cancel"
      )
    end

    it "updates the listing with session ID" do
      service.create_session(
        success_url: "https://example.com/success",
        cancel_url: "https://example.com/cancel"
      )

      listing.reload
      expect(listing.stripe_checkout_session_id).to eq("cs_test_123")
      expect(listing.payment_status).to eq("pending_payment")
    end

    it "returns the session" do
      result = service.create_session(
        success_url: "https://example.com/success",
        cancel_url: "https://example.com/cancel"
      )

      expect(result).to eq(mock_session)
    end
  end

  describe "PRICE_CONFIGS" do
    it "includes all expected checkout types" do
      expected_types = %i[
        job_post_30 job_post_60 job_post_90
        featured_7 featured_14 featured_30
      ]

      expect(StripeCheckoutService::PRICE_CONFIGS.keys).to match_array(expected_types)
    end

    it "has valid configuration for all types" do
      StripeCheckoutService::PRICE_CONFIGS.each do |type, config|
        expect(config[:name]).to be_present
        expect(config[:description]).to be_present
        expect(config[:amount]).to be_a(Integer)
        expect(config[:amount]).to be > 0
        expect(config[:currency]).to eq("usd")
        expect(config[:duration_days]).to be_a(Integer)
        expect(config[:duration_days]).to be > 0
      end
    end
  end
end
