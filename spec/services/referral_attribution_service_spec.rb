# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReferralAttributionService do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:referrer_user) { create(:user, email: "referrer@example.com") }
  let(:referee_user) { create(:user, email: "referee@different.com") }
  let(:referrer_subscription) { create(:digest_subscription, user: referrer_user, site: site) }
  let(:referee_subscription) { create(:digest_subscription, user: referee_user, site: site) }

  before do
    allow(Current).to receive(:tenant).and_return(tenant)
    allow(Current).to receive(:site).and_return(site)
  end

  describe "#attribute!" do
    subject(:service) do
      described_class.new(
        referee_subscription: referee_subscription,
        referral_code: referrer_subscription.referral_code,
        ip_address: "192.168.1.1"
      )
    end

    context "when referral is valid" do
      it "creates a pending referral" do
        result = service.attribute!

        expect(result[:success]).to be true
        expect(result[:referral]).to be_persisted
        expect(result[:referral].status).to eq("pending")
        expect(result[:referral].referrer_subscription).to eq(referrer_subscription)
        expect(result[:referral].referee_subscription).to eq(referee_subscription)
        expect(result[:referral].site).to eq(site)
      end

      it "stores hashed IP address" do
        result = service.attribute!

        expected_hash = Digest::SHA256.hexdigest("192.168.1.1")
        expect(result[:referral].referee_ip_hash).to eq(expected_hash)
      end

      it "schedules confirmation job for 24 hours later" do
        expect {
          service.attribute!
        }.to have_enqueued_job(ConfirmReferralJob)
          .on_queue("default")
      end
    end

    context "when referral code is blank" do
      subject(:service) do
        described_class.new(
          referee_subscription: referee_subscription,
          referral_code: "",
          ip_address: "192.168.1.1"
        )
      end

      it "returns error" do
        result = service.attribute!

        expect(result[:success]).to be false
        expect(result[:error]).to eq("No referral code provided")
      end

      it "does not create a referral" do
        expect { service.attribute! }.not_to change(Referral, :count)
      end
    end

    context "when referral code is nil" do
      subject(:service) do
        described_class.new(
          referee_subscription: referee_subscription,
          referral_code: nil,
          ip_address: "192.168.1.1"
        )
      end

      it "returns error" do
        result = service.attribute!

        expect(result[:success]).to be false
        expect(result[:error]).to eq("No referral code provided")
      end
    end

    context "when referral code is invalid" do
      subject(:service) do
        described_class.new(
          referee_subscription: referee_subscription,
          referral_code: "invalid_code",
          ip_address: "192.168.1.1"
        )
      end

      it "returns error" do
        result = service.attribute!

        expect(result[:success]).to be false
        expect(result[:error]).to eq("Invalid referral code")
      end
    end

    context "when referrer subscription is inactive" do
      before do
        referrer_subscription.update!(active: false)
      end

      it "returns error" do
        result = service.attribute!

        expect(result[:success]).to be false
        expect(result[:error]).to eq("Referrer subscription is inactive")
      end
    end

    context "when attempting self-referral" do
      it "returns error" do
        # Use the same subscription as both referrer and referee
        service = described_class.new(
          referee_subscription: referrer_subscription,
          referral_code: referrer_subscription.referral_code,
          ip_address: "192.168.1.1"
        )

        result = service.attribute!

        expect(result[:success]).to be false
        expect(result[:error]).to eq("Cannot refer yourself")
      end
    end

    context "when email domains match (corporate fraud prevention)" do
      let(:referrer_user) { create(:user, email: "referrer@company.com") }
      let(:referee_user) { create(:user, email: "referee@company.com") }

      it "returns error" do
        result = service.attribute!

        expect(result[:success]).to be false
        expect(result[:error]).to eq("Email domain matches referrer")
      end
    end

    context "when email domains match but are common providers" do
      let(:referrer_user) { create(:user, email: "referrer@gmail.com") }
      let(:referee_user) { create(:user, email: "referee@gmail.com") }

      it "allows the referral" do
        result = service.attribute!

        expect(result[:success]).to be true
      end

      %w[gmail.com yahoo.com outlook.com hotmail.com icloud.com].each do |provider|
        it "allows #{provider} as common provider" do
          referrer_user.update!(email: "referrer@#{provider}")
          referee_user.update!(email: "referee@#{provider}")

          result = service.attribute!
          expect(result[:success]).to be true
        end
      end
    end

    context "when same IP was used recently" do
      before do
        first_referee = create(:user)
        first_referee_subscription = create(:digest_subscription, user: first_referee, site: site)
        create(:referral,
               referrer_subscription: referrer_subscription,
               referee_subscription: first_referee_subscription,
               site: site,
               referee_ip_hash: Digest::SHA256.hexdigest("192.168.1.1"),
               created_at: 12.hours.ago)
      end

      it "returns error" do
        result = service.attribute!

        expect(result[:success]).to be false
        expect(result[:error]).to eq("Too many referrals from this IP")
      end
    end

    context "when same IP was used more than 24 hours ago" do
      before do
        first_referee = create(:user)
        first_referee_subscription = create(:digest_subscription, user: first_referee, site: site)
        create(:referral,
               referrer_subscription: referrer_subscription,
               referee_subscription: first_referee_subscription,
               site: site,
               referee_ip_hash: Digest::SHA256.hexdigest("192.168.1.1"),
               created_at: 25.hours.ago)
      end

      it "allows the referral" do
        result = service.attribute!

        expect(result[:success]).to be true
      end
    end

    context "when IP address is not provided" do
      subject(:service) do
        described_class.new(
          referee_subscription: referee_subscription,
          referral_code: referrer_subscription.referral_code,
          ip_address: nil
        )
      end

      it "creates referral without IP hash" do
        result = service.attribute!

        expect(result[:success]).to be true
        expect(result[:referral].referee_ip_hash).to be_nil
      end

      it "skips IP abuse check" do
        # Create existing referral with same IP (if there was one)
        first_referee = create(:user)
        first_referee_subscription = create(:digest_subscription, user: first_referee, site: site)
        create(:referral,
               referrer_subscription: referrer_subscription,
               referee_subscription: first_referee_subscription,
               site: site,
               referee_ip_hash: Digest::SHA256.hexdigest("192.168.1.1"),
               created_at: 1.hour.ago)

        # Should still succeed because we have no IP to check
        result = service.attribute!
        expect(result[:success]).to be true
      end
    end

    context "when referee already has a referral" do
      before do
        another_referrer = create(:user)
        another_referrer_subscription = create(:digest_subscription, user: another_referrer, site: site)
        create(:referral,
               referrer_subscription: another_referrer_subscription,
               referee_subscription: referee_subscription,
               site: site)
      end

      it "returns error" do
        result = service.attribute!

        expect(result[:success]).to be false
        expect(result[:error]).to eq("Already has a referral")
      end
    end

    context "when referral code belongs to different site" do
      let(:other_tenant) { create(:tenant, :enabled) }
      let(:other_site) { create(:site, tenant: other_tenant) }
      let(:other_referrer) { create(:user) }
      let(:other_referrer_subscription) { create(:digest_subscription, user: other_referrer, site: other_site) }

      subject(:service) do
        described_class.new(
          referee_subscription: referee_subscription,
          referral_code: other_referrer_subscription.referral_code,
          ip_address: "192.168.1.1"
        )
      end

      it "returns error (code not found in same site)" do
        result = service.attribute!

        expect(result[:success]).to be false
        expect(result[:error]).to eq("Invalid referral code")
      end
    end
  end
end
