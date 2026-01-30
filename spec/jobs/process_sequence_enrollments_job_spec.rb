# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProcessSequenceEnrollmentsJob, type: :job do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:user) { create(:user) }
  # Create subscription BEFORE sequence to avoid auto-enrollment
  let(:digest_subscription) { create(:digest_subscription, user: user, site: site, active: true) }
  # Create sequence AFTER subscription is created
  let(:email_sequence) do
    digest_subscription  # Force subscription creation first
    create(:email_sequence, :enabled, :with_steps, site: site)
  end
  let(:sequence_enrollment) { create(:sequence_enrollment, email_sequence: email_sequence, digest_subscription: digest_subscription) }
  let(:email_step) { email_sequence.email_steps.first }

  before do
    allow(Current).to receive(:tenant).and_return(tenant)
    allow(Current).to receive(:site).and_return(site)
  end

  describe "#perform" do
    context "when no due emails exist" do
      it "does not send any emails" do
        expect {
          described_class.perform_now
        }.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
      end
    end

    context "when due pending emails exist" do
      let!(:due_email) do
        create(:sequence_email,
               :due,
               sequence_enrollment: sequence_enrollment,
               email_step: email_step,
               status: :pending)
      end

      it "sends emails for due pending sequence emails" do
        expect {
          described_class.perform_now
        }.to have_enqueued_mail(SequenceMailer, :step_email)
      end

      it "marks the email as sent" do
        described_class.perform_now

        expect(due_email.reload.status).to eq("sent")
        expect(due_email.sent_at).to be_present
      end

      it "schedules the next email in the sequence" do
        expect {
          described_class.perform_now
        }.to change { sequence_enrollment.sequence_emails.count }.by(1)
      end

      it "increments current_step_position on enrollment" do
        original_position = sequence_enrollment.current_step_position

        described_class.perform_now

        expect(sequence_enrollment.reload.current_step_position).to eq(original_position + 1)
      end
    end

    context "when future emails exist" do
      let!(:future_email) do
        create(:sequence_email,
               :future,
               sequence_enrollment: sequence_enrollment,
               email_step: email_step,
               status: :pending)
      end

      it "does not process future emails" do
        expect {
          described_class.perform_now
        }.not_to have_enqueued_mail(SequenceMailer, :step_email)
      end

      it "does not mark future emails as sent" do
        described_class.perform_now

        expect(future_email.reload.status).to eq("pending")
      end
    end

    context "when subscription is inactive" do
      let(:inactive_user) { create(:user) }
      # Create inactive subscription BEFORE sequence
      let(:inactive_subscription) do
        create(:digest_subscription, :inactive, user: inactive_user, site: site)
      end
      # Create sequence AFTER inactive subscription
      let(:inactive_sequence) do
        inactive_subscription
        create(:email_sequence, :enabled, :with_steps, site: site, name: "Inactive Test")
      end
      let(:inactive_enrollment) do
        create(:sequence_enrollment, email_sequence: inactive_sequence, digest_subscription: inactive_subscription)
      end
      let!(:due_email) do
        create(:sequence_email,
               :due,
               sequence_enrollment: inactive_enrollment,
               email_step: inactive_sequence.email_steps.first,
               status: :pending)
      end

      it "does not send emails" do
        expect {
          described_class.perform_now
        }.not_to have_enqueued_mail(SequenceMailer, :step_email)
      end

      it "stops the enrollment" do
        described_class.perform_now

        expect(inactive_enrollment.reload.status).to eq("stopped")
      end
    end

    context "when an error occurs during processing" do
      let!(:due_email) do
        create(:sequence_email,
               :due,
               sequence_enrollment: sequence_enrollment,
               email_step: email_step,
               status: :pending)
      end

      before do
        allow(SequenceMailer).to receive(:step_email).and_raise(StandardError, "Test error")
      end

      it "marks the email as failed" do
        described_class.perform_now

        expect(due_email.reload.status).to eq("failed")
      end

      it "logs the error" do
        allow(Rails.logger).to receive(:error)

        described_class.perform_now

        expect(Rails.logger).to have_received(:error).with(/Failed to send sequence email #{due_email.id}/)
      end
    end

    context "tenant context" do
      let!(:due_email) do
        create(:sequence_email,
               :due,
               sequence_enrollment: sequence_enrollment,
               email_step: email_step,
               status: :pending)
      end

      it "wraps processing in correct tenant context" do
        expect(ActsAsTenant).to receive(:with_tenant).with(tenant).and_call_original

        described_class.perform_now
      end
    end

    context "with already sent emails" do
      let!(:sent_email) do
        create(:sequence_email,
               :due,
               :sent,
               sequence_enrollment: sequence_enrollment,
               email_step: email_step)
      end

      it "does not process already sent emails" do
        expect {
          described_class.perform_now
        }.not_to have_enqueued_mail(SequenceMailer, :step_email)
      end
    end

    context "with already failed emails" do
      let!(:failed_email) do
        create(:sequence_email,
               :due,
               :failed,
               sequence_enrollment: sequence_enrollment,
               email_step: email_step)
      end

      it "does not process already failed emails" do
        expect {
          described_class.perform_now
        }.not_to have_enqueued_mail(SequenceMailer, :step_email)
      end
    end
  end

  it "uses the default queue" do
    expect(described_class.new.queue_name).to eq("default")
  end

  it "can be enqueued" do
    expect {
      described_class.perform_later
    }.to have_enqueued_job(described_class)
  end
end
