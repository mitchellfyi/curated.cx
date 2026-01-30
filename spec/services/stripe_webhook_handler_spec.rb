# frozen_string_literal: true

require "rails_helper"

RSpec.describe StripeWebhookHandler do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { create(:site, tenant: tenant) }
  let(:category) { create(:category, tenant: tenant, site: site) }
  let!(:listing) do
    create(:listing, :job, site: site, tenant: tenant, category: category,
           stripe_checkout_session_id: "cs_test_123",
           payment_status: :pending_payment)
  end

  before do
    Current.tenant = tenant
    Current.site = site
  end

  describe "#process" do
    describe "checkout.session.completed" do
      let(:session_object) do
        double("Stripe::Checkout::Session",
          id: "cs_test_123",
          payment_intent: "pi_test_456",
          customer_email: "customer@example.com",
          customer_details: double(email: "customer@example.com"),
          metadata: {
            "checkout_type" => "job_post_30",
            "duration_days" => "30",
            "listing_id" => listing.id.to_s
          },
          amount_total: 99_00,
          currency: "usd")
      end

      let(:event) do
        double("Stripe::Event",
          type: "checkout.session.completed",
          data: double(object: session_object))
      end

      before do
        allow(PaymentReceiptMailer).to receive_message_chain(:receipt, :deliver_later)
      end

      it "marks the listing as paid" do
        described_class.new(event).process

        listing.reload
        expect(listing.payment_status).to eq("paid")
        expect(listing.paid).to be true
        expect(listing.stripe_payment_intent_id).to eq("pi_test_456")
      end

      it "sets expiry date for job posts" do
        freeze_time do
          described_class.new(event).process

          listing.reload
          expect(listing.expires_at).to be_within(1.second).of(30.days.from_now)
          expect(listing.published_at).to be_present
        end
      end

      it "sends payment receipt email" do
        expect(PaymentReceiptMailer).to receive(:receipt).with(listing, session_object)

        described_class.new(event).process
      end
    end

    describe "checkout.session.completed with featured" do
      let(:session_object) do
        double("Stripe::Checkout::Session",
          id: "cs_test_123",
          payment_intent: "pi_test_456",
          customer_email: "customer@example.com",
          customer_details: double(email: "customer@example.com"),
          metadata: {
            "checkout_type" => "featured_14",
            "duration_days" => "14",
            "listing_id" => listing.id.to_s
          },
          amount_total: 89_00,
          currency: "usd")
      end

      let(:event) do
        double("Stripe::Event",
          type: "checkout.session.completed",
          data: double(object: session_object))
      end

      before do
        allow(PaymentReceiptMailer).to receive_message_chain(:receipt, :deliver_later)
      end

      it "sets featured dates" do
        freeze_time do
          described_class.new(event).process

          listing.reload
          expect(listing.featured_from).to be_within(1.second).of(Time.current)
          expect(listing.featured_until).to be_within(1.second).of(14.days.from_now)
        end
      end
    end

    describe "checkout.session.expired" do
      let(:session_object) do
        double("Stripe::Checkout::Session", id: "cs_test_123")
      end

      let(:event) do
        double("Stripe::Event",
          type: "checkout.session.expired",
          data: double(object: session_object))
      end

      it "resets payment status to unpaid" do
        described_class.new(event).process

        listing.reload
        expect(listing.payment_status).to eq("unpaid")
      end
    end

    describe "charge.refunded" do
      let!(:paid_listing) do
        create(:listing, :job, site: site, tenant: tenant, category: category,
               stripe_payment_intent_id: "pi_test_456",
               payment_status: :paid,
               paid: true,
               featured_from: Time.current,
               featured_until: 14.days.from_now)
      end

      let(:charge_object) do
        double("Stripe::Charge", payment_intent: "pi_test_456")
      end

      let(:event) do
        double("Stripe::Event",
          type: "charge.refunded",
          data: double(object: charge_object))
      end

      it "marks listing as refunded" do
        described_class.new(event).process

        paid_listing.reload
        expect(paid_listing.payment_status).to eq("refunded")
        expect(paid_listing.paid).to be false
      end

      it "removes featured benefits" do
        described_class.new(event).process

        paid_listing.reload
        expect(paid_listing.featured_from).to be_nil
        expect(paid_listing.featured_until).to be_nil
      end
    end

    describe "unhandled event types" do
      let(:event) do
        double("Stripe::Event", type: "some.unknown.event")
      end

      it "returns true without error" do
        expect(described_class.new(event).process).to be true
      end
    end
  end
end
