# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReferralMailer, type: :mailer do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:referrer_user) { create(:user, email: "referrer@example.com") }
  let(:referee_user) { create(:user, email: "referee@example.com") }
  let(:referrer_subscription) { create(:digest_subscription, user: referrer_user, site: site) }
  let(:referee_subscription) { create(:digest_subscription, user: referee_user, site: site) }
  let(:referral) { create(:referral, :confirmed, referrer_subscription: referrer_subscription, referee_subscription: referee_subscription, site: site) }

  before do
    allow(Current).to receive(:tenant).and_return(tenant)
    allow(Current).to receive(:site).and_return(site)
  end

  describe "#referral_confirmed" do
    let(:mail) { described_class.referral_confirmed(referral) }

    it "sends to the referrer email" do
      expect(mail.to).to eq([ referrer_user.email ])
    end

    it "includes site name in subject" do
      expect(mail.subject).to include(site.name)
    end

    it "includes referral link in body" do
      expect(mail.body.encoded).to include(referrer_subscription.referral_code)
    end

    it "includes referee info in body" do
      expect(mail.body.encoded).to include("new subscriber")
    end

    context "with site email setting" do
      before do
        allow(site).to receive(:setting).with("email.from_address").and_return("newsletter@customsite.com")
        allow(tenant).to receive(:setting).with("email.from_address").and_return(nil)
      end

      it "uses site email as from address" do
        expect(mail.from).to include("newsletter@customsite.com")
      end
    end

    context "with tenant email setting" do
      before do
        allow(site).to receive(:setting).with("email.from_address").and_return(nil)
        allow(tenant).to receive(:setting).with("email.from_address").and_return("newsletter@tenant.com")
      end

      it "uses tenant email as from address" do
        expect(mail.from).to include("newsletter@tenant.com")
      end
    end

    context "without email settings" do
      before do
        allow(site).to receive(:setting).with("email.from_address").and_return(nil)
        allow(tenant).to receive(:setting).with("email.from_address").and_return(nil)
        allow(site).to receive(:primary_hostname).and_return("example.com")
      end

      it "uses default from address with site hostname" do
        expect(mail.from).to include("referrals@example.com")
      end
    end
  end

  describe "#reward_unlocked" do
    let(:tier) { create(:referral_reward_tier, :digital_download, site: site, name: "Exclusive Ebook") }
    let(:mail) { described_class.reward_unlocked(referrer_subscription, tier) }

    it "sends to the referrer email" do
      expect(mail.to).to eq([ referrer_user.email ])
    end

    it "includes reward name in subject" do
      expect(mail.subject).to include("Exclusive Ebook")
    end

    it "includes site name in subject" do
      expect(mail.subject).to include(site.name)
    end

    it "includes reward name in body" do
      expect(mail.body.encoded).to include("Exclusive Ebook")
    end

    it "includes referral link in body" do
      expect(mail.body.encoded).to include(referrer_subscription.referral_code)
    end

    context "with digital_download reward" do
      let(:tier) { create(:referral_reward_tier, :digital_download, site: site) }

      it "includes download URL in body" do
        expect(mail.body.encoded).to include("example.com/download")
      end
    end

    context "with featured_mention reward" do
      let(:tier) { create(:referral_reward_tier, :featured_mention, site: site) }

      it "includes mention details in body" do
        expect(mail.body.encoded).to include("Featured in next newsletter")
      end
    end

    context "with custom reward" do
      let(:tier) { create(:referral_reward_tier, :custom, site: site) }

      it "includes instructions in body" do
        expect(mail.body.encoded).to include("Contact us")
      end
    end
  end
end
