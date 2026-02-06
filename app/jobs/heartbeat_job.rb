# frozen_string_literal: true

require "socket"

# Heartbeat job runs periodically to verify job scheduling is working
# Writes a log entry every 5 minutes to verify recurring execution
class HeartbeatJob < ApplicationJob
  queue_as :default

  def perform
    hostname = begin
      Socket.gethostname
    rescue SocketError, SystemCallError
      "unknown"
    end
    log_entry = {
      timestamp: Time.current.iso8601,
      environment: Rails.env,
      hostname: hostname,
      message: "Heartbeat job executed successfully"
    }

    # Write to Rails logger (structured format for easy parsing)
    Rails.logger.info("[HEARTBEAT] #{log_entry.to_json}")

    # Also create a database record for verification
    HeartbeatLog.create!(
      executed_at: Time.current,
      environment: Rails.env,
      hostname: hostname
    )
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.error("[HEARTBEAT] Failed to create HeartbeatLog: #{e.message}")
  end
end
