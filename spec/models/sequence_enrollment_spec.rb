# frozen_string_literal: true

# == Schema Information
#
# Table name: sequence_enrollments
#
#  id                     :bigint           not null, primary key
#  completed_at           :datetime
#  current_step_position  :integer          default(0), not null
#  enrolled_at            :datetime         not null
#  status                 :integer          default("active"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  digest_subscription_id :bigint           not null
#  email_sequence_id      :bigint           not null
#
# Indexes
#
#  idx_enrollments_sequence_subscription                 (email_sequence_id,digest_subscription_id) UNIQUE
#  index_sequence_enrollments_on_digest_subscription_id  (digest_subscription_id)
#  index_sequence_enrollments_on_email_sequence_id       (email_sequence_id)
#  index_sequence_enrollments_on_status                  (status)
#
# Foreign Keys
#
#  fk_rails_...  (digest_subscription_id => digest_subscriptions.id)
#  fk_rails_...  (email_sequence_id => email_sequences.id)
#
require "rails_helper"

RSpec.describe SequenceEnrollment, type: :model do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:user) { create(:user) }
  let(:digest_subscription) { create(:digest_subscription, user: user, site: site) }
  let(:email_sequence) { create(:email_sequence, :with_steps, site: site) }

  before do
    allow(Current).to receive(:tenant).and_return(tenant)
    allow(Current).to receive(:site).and_return(site)
  end

  describe "associations" do
    it { is_expected.to belong_to(:email_sequence) }
    it { is_expected.to belong_to(:digest_subscription) }
    it { is_expected.to have_many(:sequence_emails).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:sequence_enrollment, email_sequence: email_sequence, digest_subscription: digest_subscription) }

    it { is_expected.to validate_presence_of(:enrolled_at) }

    it "validates uniqueness of email_sequence_id scoped to digest_subscription_id" do
      create(:sequence_enrollment, email_sequence: email_sequence, digest_subscription: digest_subscription)
      duplicate = build(:sequence_enrollment, email_sequence: email_sequence, digest_subscription: digest_subscription)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:email_sequence_id]).to include("has already been taken")
    end

    it "allows same subscription to enroll in different sequences" do
      other_sequence = create(:email_sequence, site: site)
      create(:sequence_enrollment, email_sequence: email_sequence, digest_subscription: digest_subscription)
      other_enrollment = build(:sequence_enrollment, email_sequence: other_sequence, digest_subscription: digest_subscription)

      expect(other_enrollment).to be_valid
    end
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:status).with_values(active: 0, completed: 1, stopped: 2) }
  end

  describe "scopes" do
    describe ".for_sequence" do
      let(:other_sequence) { create(:email_sequence, site: site) }
      let(:other_user) { create(:user) }
      let(:other_subscription) { create(:digest_subscription, user: other_user, site: site) }
      let!(:enrollment1) { create(:sequence_enrollment, email_sequence: email_sequence, digest_subscription: digest_subscription) }
      let!(:enrollment2) { create(:sequence_enrollment, email_sequence: other_sequence, digest_subscription: other_subscription) }

      it "filters by sequence" do
        expect(described_class.for_sequence(email_sequence)).to include(enrollment1)
        expect(described_class.for_sequence(email_sequence)).not_to include(enrollment2)
      end
    end
  end

  describe "#stop!" do
    let(:enrollment) { create(:sequence_enrollment, email_sequence: email_sequence, digest_subscription: digest_subscription, status: :active) }

    context "when active" do
      it "transitions to stopped" do
        expect(enrollment.stop!).to be true
        expect(enrollment.status).to eq("stopped")
      end
    end

    context "when not active" do
      it "returns false for completed enrollment" do
        enrollment.update!(status: :completed, completed_at: Time.current)

        expect(enrollment.stop!).to be false
        expect(enrollment.status).to eq("completed")
      end

      it "returns false for stopped enrollment" do
        enrollment.update!(status: :stopped)

        expect(enrollment.stop!).to be false
      end
    end
  end

  describe "#complete!" do
    let(:enrollment) { create(:sequence_enrollment, email_sequence: email_sequence, digest_subscription: digest_subscription, status: :active) }

    context "when active" do
      it "transitions to completed" do
        freeze_time do
          expect(enrollment.complete!).to be true
          expect(enrollment.status).to eq("completed")
          expect(enrollment.completed_at).to eq(Time.current)
        end
      end
    end

    context "when not active" do
      it "returns false for completed enrollment" do
        enrollment.update!(status: :completed, completed_at: Time.current)

        expect(enrollment.complete!).to be false
      end

      it "returns false for stopped enrollment" do
        enrollment.update!(status: :stopped)

        expect(enrollment.complete!).to be false
      end
    end
  end

  describe "#next_step" do
    let(:enrollment) { create(:sequence_enrollment, email_sequence: email_sequence, digest_subscription: digest_subscription, current_step_position: 0) }

    it "returns the first step when current_step_position is 0" do
      first_step = email_sequence.email_steps.ordered.first
      expect(enrollment.next_step).to eq(first_step)
    end

    it "returns the second step when current_step_position is 1" do
      enrollment.update!(current_step_position: 1)
      second_step = email_sequence.email_steps.ordered.second
      expect(enrollment.next_step).to eq(second_step)
    end

    it "returns nil when all steps completed" do
      enrollment.update!(current_step_position: email_sequence.email_steps.count)
      expect(enrollment.next_step).to be_nil
    end
  end

  describe "#schedule_next_email!" do
    let(:enrollment) { create(:sequence_enrollment, email_sequence: email_sequence, digest_subscription: digest_subscription, current_step_position: 0, enrolled_at: Time.current) }

    context "when active with remaining steps" do
      it "creates a sequence email" do
        expect {
          enrollment.schedule_next_email!
        }.to change(SequenceEmail, :count).by(1)
      end

      it "schedules for the correct time based on first step delay" do
        freeze_time do
          enrollment.schedule_next_email!

          first_step = email_sequence.email_steps.ordered.first
          sequence_email = enrollment.sequence_emails.last
          expected_time = enrollment.enrolled_at + first_step.delay_duration

          expect(sequence_email.scheduled_for).to eq(expected_time)
        end
      end

      it "increments current_step_position" do
        expect {
          enrollment.schedule_next_email!
        }.to change { enrollment.reload.current_step_position }.from(0).to(1)
      end
    end

    context "when no remaining steps" do
      before do
        enrollment.update!(current_step_position: email_sequence.email_steps.count)
      end

      it "completes the enrollment" do
        enrollment.schedule_next_email!

        expect(enrollment.status).to eq("completed")
      end

      it "does not create a sequence email" do
        expect {
          enrollment.schedule_next_email!
        }.not_to change(SequenceEmail, :count)
      end
    end

    context "when not active" do
      before do
        enrollment.update!(status: :stopped)
      end

      it "does not create a sequence email" do
        expect {
          enrollment.schedule_next_email!
        }.not_to change(SequenceEmail, :count)
      end
    end

    context "when scheduling subsequent steps" do
      before do
        # Schedule and "send" first email
        enrollment.schedule_next_email!
        enrollment.sequence_emails.first.update!(scheduled_for: 1.day.ago)
      end

      it "calculates scheduled_for based on previous email scheduled_for" do
        freeze_time do
          enrollment.schedule_next_email!

          second_step = email_sequence.email_steps.ordered.second
          sequence_email = enrollment.sequence_emails.last
          previous_email = enrollment.sequence_emails.order(scheduled_for: :desc).offset(1).first
          expected_time = previous_email.scheduled_for + second_step.delay_duration

          expect(sequence_email.scheduled_for).to eq(expected_time)
        end
      end
    end
  end

  describe "factory" do
    it "creates a valid sequence enrollment" do
      enrollment = build(:sequence_enrollment, email_sequence: email_sequence, digest_subscription: digest_subscription)
      expect(enrollment).to be_valid
    end

    it "creates a valid enrollment with :completed trait" do
      enrollment = build(:sequence_enrollment, :completed, email_sequence: email_sequence, digest_subscription: digest_subscription)
      expect(enrollment).to be_valid
      expect(enrollment.status).to eq("completed")
      expect(enrollment.completed_at).to be_present
    end

    it "creates a valid enrollment with :stopped trait" do
      enrollment = build(:sequence_enrollment, :stopped, email_sequence: email_sequence, digest_subscription: digest_subscription)
      expect(enrollment).to be_valid
      expect(enrollment.status).to eq("stopped")
    end
  end
end
