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
class HeartbeatLog < ApplicationRecord
  # Validations
  validates :executed_at, presence: true
  validates :environment, presence: true
  validates :hostname, presence: true

  # Scopes
  scope :recent, -> { order(executed_at: :desc) }
  scope :by_environment, ->(env) { where(environment: env) }
  scope :by_hostname, ->(host) { where(hostname: host) }

  # Class methods
  def self.latest
    recent.first
  end

  def self.verify_recent(within: 10.minutes)
    latest = self.latest
    return false unless latest

    Time.current - latest.executed_at <= within
  end
end
