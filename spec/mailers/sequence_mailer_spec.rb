# frozen_string_literal: true

require "rails_helper"

RSpec.describe SequenceMailer, type: :mailer do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:user) { create(:user, email: "subscriber@example.com") }
  # Create subscription BEFORE sequence to avoid auto-enrollment
  let(:digest_subscription) { create(:digest_subscription, user: user, site: site, active: true) }
  let(:email_sequence) do
    digest_subscription
    create(:email_sequence, :enabled, :with_steps, site: site)
  end
  let(:sequence_enrollment) { create(:sequence_enrollment, email_sequence: email_sequence, digest_subscription: digest_subscription) }
  let(:email_step) { email_sequence.email_steps.first }
  let(:sequence_email) { create(:sequence_email, sequence_enrollment: sequence_enrollment, email_step: email_step) }

  before do
    allow(Current).to receive(:tenant).and_return(tenant)
    allow(Current).to receive(:site).and_return(site)
  end

  describe "#step_email" do
    let(:mail) { described_class.step_email(sequence_email) }

    it "sends to the subscriber email" do
      expect(mail.to).to eq([ user.email ])
    end

    it "uses the step subject" do
      expect(mail.subject).to eq(email_step.subject)
    end

    it "includes step body in html content" do
      expect(mail.body.encoded).to include(email_step.body_html)
    end

    it "includes unsubscribe link in body" do
      expect(mail.body.encoded).to include(digest_subscription.unsubscribe_token)
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
        expect(mail.from).to include("sequence@example.com")
      end
    end

    context "when subscription is inactive" do
      let(:inactive_user) { create(:user) }
      let(:inactive_subscription) do
        create(:digest_subscription, :inactive, user: inactive_user, site: site)
      end
      let(:inactive_sequence) do
        inactive_subscription
        create(:email_sequence, :enabled, :with_steps, site: site, name: "Inactive Test")
      end
      let(:inactive_enrollment) do
        create(:sequence_enrollment, email_sequence: inactive_sequence, digest_subscription: inactive_subscription)
      end
      let(:inactive_sequence_email) do
        create(:sequence_email, sequence_enrollment: inactive_enrollment, email_step: inactive_sequence.email_steps.first)
      end

      it "returns nil" do
        mail = described_class.step_email(inactive_sequence_email)
        # When a mailer action returns early, the mail object exists but has no message
        expect(mail.message.to).to be_nil
      end
    end
  end
end
