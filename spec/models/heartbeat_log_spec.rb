# frozen_string_literal: true

# == Schema Information
#
# Table name: heartbeat_logs
#
#  id          :bigint           not null, primary key
#  environment :string           not null
#  executed_at :datetime         not null
#  hostname    :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_heartbeat_logs_on_environment_and_executed_at  (environment,executed_at)
#  index_heartbeat_logs_on_executed_at                  (executed_at)
#
require 'rails_helper'

RSpec.describe HeartbeatLog, type: :model do
  describe "validations" do
    it "requires executed_at" do
      log = HeartbeatLog.new(environment: "test", hostname: "test-host")
      expect(log).not_to be_valid
      expect(log.errors[:executed_at]).to be_present
    end

    it "requires environment" do
      log = HeartbeatLog.new(executed_at: Time.current, hostname: "test-host")
      expect(log).not_to be_valid
      expect(log.errors[:environment]).to be_present
    end

    it "requires hostname" do
      log = HeartbeatLog.new(executed_at: Time.current, environment: "test")
      expect(log).not_to be_valid
      expect(log.errors[:hostname]).to be_present
    end
  end

  describe "scopes" do
    let!(:old_log) { create(:heartbeat_log, executed_at: 1.hour.ago) }
    let!(:recent_log) { create(:heartbeat_log, executed_at: 5.minutes.ago) }
    let!(:latest_log) { create(:heartbeat_log, executed_at: 1.minute.ago) }

    it "orders by executed_at descending for recent scope" do
      expect(HeartbeatLog.recent.first).to eq(latest_log)
      expect(HeartbeatLog.recent.last).to eq(old_log)
    end

    it "filters by environment" do
      test_log = create(:heartbeat_log, environment: "test")
      prod_log = create(:heartbeat_log, environment: "production")

      expect(HeartbeatLog.by_environment("test")).to include(test_log)
      expect(HeartbeatLog.by_environment("test")).not_to include(prod_log)
    end

    it "filters by hostname" do
      host1_log = create(:heartbeat_log, hostname: "host1")
      host2_log = create(:heartbeat_log, hostname: "host2")

      expect(HeartbeatLog.by_hostname("host1")).to include(host1_log)
      expect(HeartbeatLog.by_hostname("host1")).not_to include(host2_log)
    end
  end

  describe ".latest" do
    it "returns the most recent heartbeat log" do
      old_log = create(:heartbeat_log, executed_at: 1.hour.ago)
      latest_log = create(:heartbeat_log, executed_at: 1.minute.ago)

      expect(HeartbeatLog.latest).to eq(latest_log)
    end
  end

  describe ".verify_recent" do
    it "returns true if latest heartbeat is within threshold" do
      create(:heartbeat_log, executed_at: 3.minutes.ago)

      expect(HeartbeatLog.verify_recent(within: 10.minutes)).to be true
    end

    it "returns false if latest heartbeat is older than threshold" do
      create(:heartbeat_log, executed_at: 15.minutes.ago)

      expect(HeartbeatLog.verify_recent(within: 10.minutes)).to be false
    end

    it "returns false if no heartbeats exist" do
      HeartbeatLog.delete_all

      expect(HeartbeatLog.verify_recent).to be false
    end
  end
end
