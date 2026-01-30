# frozen_string_literal: true

require "rails_helper"

RSpec.describe SequenceEmail, type: :model do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:user) { create(:user) }
  let(:digest_subscription) { create(:digest_subscription, user: user, site: site) }
  let(:email_sequence) { create(:email_sequence, :with_steps, site: site) }
  let(:sequence_enrollment) { create(:sequence_enrollment, email_sequence: email_sequence, digest_subscription: digest_subscription) }
  let(:email_step) { email_sequence.email_steps.first }

  before do
    allow(Current).to receive(:tenant).and_return(tenant)
    allow(Current).to receive(:site).and_return(site)
  end

  describe "associations" do
    it { is_expected.to belong_to(:sequence_enrollment) }
    it { is_expected.to belong_to(:email_step) }
  end

  describe "validations" do
    subject { build(:sequence_email, sequence_enrollment: sequence_enrollment, email_step: email_step) }

    it { is_expected.to validate_presence_of(:scheduled_for) }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:status).with_values(pending: 0, sent: 1, failed: 2) }
  end

  describe "scopes" do
    let!(:pending_email) { create(:sequence_email, sequence_enrollment: sequence_enrollment, email_step: email_step, status: :pending) }
    let!(:sent_email) { create(:sequence_email, :sent, sequence_enrollment: sequence_enrollment, email_step: email_step) }
    let!(:failed_email) { create(:sequence_email, :failed, sequence_enrollment: sequence_enrollment, email_step: email_step) }

    describe ".pending" do
      it "returns only pending emails" do
        expect(described_class.pending).to include(pending_email)
        expect(described_class.pending).not_to include(sent_email)
        expect(described_class.pending).not_to include(failed_email)
      end
    end

    describe ".due" do
      let!(:due_email) { create(:sequence_email, :due, sequence_enrollment: sequence_enrollment, email_step: email_step) }
      let!(:future_email) { create(:sequence_email, :future, sequence_enrollment: sequence_enrollment, email_step: email_step) }

      it "returns emails scheduled for now or earlier" do
        expect(described_class.due).to include(due_email)
        expect(described_class.due).not_to include(future_email)
      end
    end
  end

  describe "#mark_sent!" do
    let(:sequence_email) { create(:sequence_email, sequence_enrollment: sequence_enrollment, email_step: email_step, status: :pending) }

    it "transitions to sent" do
      freeze_time do
        sequence_email.mark_sent!

        expect(sequence_email.status).to eq("sent")
        expect(sequence_email.sent_at).to eq(Time.current)
      end
    end
  end

  describe "#mark_failed!" do
    let(:sequence_email) { create(:sequence_email, sequence_enrollment: sequence_enrollment, email_step: email_step, status: :pending) }

    it "transitions to failed" do
      sequence_email.mark_failed!

      expect(sequence_email.status).to eq("failed")
    end
  end

  describe "factory" do
    it "creates a valid sequence email" do
      email = build(:sequence_email, sequence_enrollment: sequence_enrollment, email_step: email_step)
      expect(email).to be_valid
    end

    it "creates a valid email with :sent trait" do
      email = build(:sequence_email, :sent, sequence_enrollment: sequence_enrollment, email_step: email_step)
      expect(email).to be_valid
      expect(email.status).to eq("sent")
      expect(email.sent_at).to be_present
    end

    it "creates a valid email with :failed trait" do
      email = build(:sequence_email, :failed, sequence_enrollment: sequence_enrollment, email_step: email_step)
      expect(email).to be_valid
      expect(email.status).to eq("failed")
    end

    it "creates a valid email with :due trait" do
      email = build(:sequence_email, :due, sequence_enrollment: sequence_enrollment, email_step: email_step)
      expect(email).to be_valid
      expect(email.scheduled_for).to be < Time.current
    end

    it "creates a valid email with :future trait" do
      email = build(:sequence_email, :future, sequence_enrollment: sequence_enrollment, email_step: email_step)
      expect(email).to be_valid
      expect(email.scheduled_for).to be > Time.current
    end
  end
end
