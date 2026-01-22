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
FactoryBot.define do
  factory :heartbeat_log do
    executed_at { Time.current }
    environment { Rails.env }
    sequence(:hostname) { |n| "host-#{n}" }
  end
end
