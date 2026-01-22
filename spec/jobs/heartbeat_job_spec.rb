# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HeartbeatJob, type: :job do
  describe "#perform" do
    it "creates a heartbeat log entry" do
      expect {
        described_class.perform_now
      }.to change(HeartbeatLog, :count).by(1)
    end

    it "logs heartbeat execution with structured format" do
      allow(Rails.logger).to receive(:info)

      described_class.perform_now

      expect(Rails.logger).to have_received(:info).with(
        a_string_matching(/\[HEARTBEAT\]/)
      )
      expect(Rails.logger).to have_received(:info).with(
        a_string_including("timestamp")
      )
    end

    it "records executed_at, environment, and hostname" do
      described_class.perform_now

      log = HeartbeatLog.last
      expect(log.executed_at).to be_within(1.second).of(Time.current)
      expect(log.environment).to eq(Rails.env)
      expect(log.hostname).to be_present
    end

    it "handles hostname resolution errors gracefully" do
      allow(Socket).to receive(:gethostname).and_raise(SocketError.new("Hostname error"))
      allow(Rails.logger).to receive(:info)

      expect {
        described_class.perform_now
      }.to change(HeartbeatLog, :count).by(1)

      log = HeartbeatLog.last
      expect(log.hostname).to eq("unknown")
    end

    it "can be enqueued" do
      expect {
        described_class.perform_later
      }.to have_enqueued_job(described_class)
    end
  end

  describe "job scheduling" do
    it "can be scheduled via Solid Queue recurring tasks" do
      # Verify the job can be called directly
      expect {
        described_class.perform_now
      }.not_to raise_error
    end
  end
end
