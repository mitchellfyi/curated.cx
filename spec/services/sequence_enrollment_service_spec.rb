# frozen_string_literal: true

require "rails_helper"

RSpec.describe SequenceEnrollmentService do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:user) { create(:user) }
  # Create subscription before any sequences exist to avoid auto-enrollment
  let(:digest_subscription) { create(:digest_subscription, user: user, site: site) }

  before do
    allow(Current).to receive(:tenant).and_return(tenant)
    allow(Current).to receive(:site).and_return(site)
  end

  describe "#enroll_on_subscription!" do
    subject(:service) { described_class.new(digest_subscription) }

    context "when digest_subscription is nil" do
      subject(:service) { described_class.new(nil) }

      it "returns empty array" do
        expect(service.enroll_on_subscription!).to eq([])
      end
    end

    context "when no sequences exist" do
      it "returns empty array" do
        expect(service.enroll_on_subscription!).to eq([])
      end
    end

    context "when matching enabled sequences exist" do
      # Create sequence AFTER digest_subscription to test manual enrollment
      let!(:enabled_sequence) do
        # Force subscription to be created first
        digest_subscription
        create(:email_sequence, :enabled, :with_steps, site: site, trigger_type: :subscriber_joined)
      end

      it "creates an enrollment" do
        expect {
          service.enroll_on_subscription!
        }.to change(SequenceEnrollment, :count).by(1)
      end

      it "returns the created enrollments" do
        enrollments = service.enroll_on_subscription!

        expect(enrollments.length).to eq(1)
        expect(enrollments.first.email_sequence).to eq(enabled_sequence)
        expect(enrollments.first.digest_subscription).to eq(digest_subscription)
      end

      it "sets enrollment attributes correctly" do
        freeze_time do
          enrollments = service.enroll_on_subscription!
          enrollment = enrollments.first

          expect(enrollment.status).to eq("active")
          expect(enrollment.enrolled_at).to eq(Time.current)
          expect(enrollment.current_step_position).to eq(1) # After scheduling first email
        end
      end

      it "schedules the first email" do
        expect {
          service.enroll_on_subscription!
        }.to change(SequenceEmail, :count).by(1)
      end
    end

    context "when disabled sequences exist" do
      let!(:disabled_sequence) do
        digest_subscription
        create(:email_sequence, :with_steps, site: site, trigger_type: :subscriber_joined, enabled: false)
      end

      it "does not create an enrollment" do
        expect {
          service.enroll_on_subscription!
        }.not_to change(SequenceEnrollment, :count)
      end

      it "returns empty array" do
        expect(service.enroll_on_subscription!).to eq([])
      end
    end

    context "when referral_milestone sequences exist" do
      let!(:referral_sequence) do
        digest_subscription
        create(:email_sequence, :enabled, :referral_milestone_trigger, site: site)
      end

      it "does not enroll in referral_milestone sequences" do
        expect {
          service.enroll_on_subscription!
        }.not_to change(SequenceEnrollment, :count)
      end
    end

    context "when already enrolled" do
      # Create sequence BEFORE subscription so auto-enrollment happens
      let!(:enabled_sequence) { create(:email_sequence, :enabled, :with_steps, site: site, trigger_type: :subscriber_joined) }
      # Creating subscription will auto-enroll due to callback
      let!(:subscription_with_enrollment) { create(:digest_subscription, user: user, site: site) }
      subject(:service) { described_class.new(subscription_with_enrollment) }

      it "does not create duplicate enrollment" do
        # Should already be enrolled from after_create_commit callback
        expect(SequenceEnrollment.where(digest_subscription: subscription_with_enrollment, email_sequence: enabled_sequence).count).to eq(1)

        expect {
          service.enroll_on_subscription!
        }.not_to change(SequenceEnrollment, :count)
      end

      it "returns empty array" do
        expect(service.enroll_on_subscription!).to eq([])
      end
    end

    context "with multiple matching sequences" do
      let!(:sequence1) do
        digest_subscription
        create(:email_sequence, :enabled, :with_steps, site: site, trigger_type: :subscriber_joined, name: "Welcome 1")
      end
      let!(:sequence2) do
        create(:email_sequence, :enabled, :with_steps, site: site, trigger_type: :subscriber_joined, name: "Welcome 2")
      end

      it "enrolls in all matching sequences" do
        expect {
          service.enroll_on_subscription!
        }.to change(SequenceEnrollment, :count).by(2)
      end

      it "schedules first email for each sequence" do
        expect {
          service.enroll_on_subscription!
        }.to change(SequenceEmail, :count).by(2)
      end
    end

    context "tenant isolation" do
      let(:other_tenant) { create(:tenant, :enabled) }
      let(:other_site) { create(:site, tenant: other_tenant) }
      let!(:other_sequence) do
        digest_subscription
        create(:email_sequence, :enabled, :with_steps, site: other_site, trigger_type: :subscriber_joined)
      end

      it "does not enroll in sequences from other sites" do
        expect {
          service.enroll_on_subscription!
        }.not_to change(SequenceEnrollment, :count)
      end
    end
  end

  describe "#enroll_on_referral_milestone!" do
    subject(:service) { described_class.new(digest_subscription) }

    context "when digest_subscription is nil" do
      subject(:service) { described_class.new(nil) }

      it "returns empty array" do
        expect(service.enroll_on_referral_milestone!(3)).to eq([])
      end
    end

    context "when no sequences exist" do
      it "returns empty array" do
        expect(service.enroll_on_referral_milestone!(3)).to eq([])
      end
    end

    context "when matching milestone sequence exists" do
      let!(:milestone_sequence) do
        digest_subscription
        create(:email_sequence, :enabled, :with_steps, :referral_milestone_trigger, site: site)
      end

      it "enrolls when milestone matches" do
        expect {
          service.enroll_on_referral_milestone!(3)
        }.to change(SequenceEnrollment, :count).by(1)
      end

      it "does not enroll when milestone does not match" do
        expect {
          service.enroll_on_referral_milestone!(5)
        }.not_to change(SequenceEnrollment, :count)
      end

      it "returns the created enrollment" do
        enrollments = service.enroll_on_referral_milestone!(3)

        expect(enrollments.length).to eq(1)
        expect(enrollments.first.email_sequence).to eq(milestone_sequence)
      end

      it "schedules the first email" do
        expect {
          service.enroll_on_referral_milestone!(3)
        }.to change(SequenceEmail, :count).by(1)
      end
    end

    context "when subscriber_joined sequences exist" do
      # Create the sequence AFTER subscription is created (to avoid auto-enrollment during subscription creation)
      let!(:subscriber_sequence) do
        digest_subscription
        create(:email_sequence, :enabled, :with_steps, site: site, trigger_type: :subscriber_joined)
      end

      it "does not enroll in subscriber_joined sequences when calling enroll_on_referral_milestone!" do
        # First verify no enrollments exist yet
        expect(SequenceEnrollment.count).to eq(0)

        # This should NOT enroll in subscriber_joined sequences
        expect {
          service.enroll_on_referral_milestone!(3)
        }.not_to change(SequenceEnrollment, :count)
      end
    end

    context "when already enrolled in milestone sequence" do
      let!(:milestone_sequence) do
        digest_subscription
        create(:email_sequence, :enabled, :with_steps, :referral_milestone_trigger, site: site)
      end

      before do
        # Manually enroll first
        service.enroll_on_referral_milestone!(3)
      end

      it "does not create duplicate enrollment" do
        expect(SequenceEnrollment.count).to eq(1)

        expect {
          service.enroll_on_referral_milestone!(3)
        }.not_to change(SequenceEnrollment, :count)
      end
    end

    context "with multiple milestones" do
      let!(:milestone3_sequence) do
        digest_subscription
        create(:email_sequence, :enabled, :with_steps, site: site, trigger_type: :referral_milestone, trigger_config: { milestone: 3 }, name: "Milestone 3")
      end
      let!(:milestone5_sequence) do
        create(:email_sequence, :enabled, :with_steps, site: site, trigger_type: :referral_milestone, trigger_config: { milestone: 5 }, name: "Milestone 5")
      end

      it "only enrolls in the matching milestone sequence" do
        enrollments = service.enroll_on_referral_milestone!(3)

        expect(enrollments.length).to eq(1)
        expect(enrollments.first.email_sequence).to eq(milestone3_sequence)
      end

      it "handles integer string milestone parameter" do
        enrollments = service.enroll_on_referral_milestone!("3")

        expect(enrollments.length).to eq(1)
        expect(enrollments.first.email_sequence).to eq(milestone3_sequence)
      end
    end
  end
end
