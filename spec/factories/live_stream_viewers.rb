# frozen_string_literal: true

# == Schema Information
#
# Table name: live_stream_viewers
#
#  id               :bigint           not null, primary key
#  duration_seconds :integer
#  joined_at        :datetime         not null
#  left_at          :datetime
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  live_stream_id   :bigint           not null
#  session_id       :string
#  site_id          :bigint           not null
#  user_id          :bigint
#
# Indexes
#
#  index_live_stream_viewers_on_live_stream_id      (live_stream_id)
#  index_live_stream_viewers_on_site_id             (site_id)
#  index_live_stream_viewers_on_stream_and_session  (live_stream_id,session_id) UNIQUE WHERE (session_id IS NOT NULL)
#  index_live_stream_viewers_on_stream_and_user     (live_stream_id,user_id) UNIQUE WHERE (user_id IS NOT NULL)
#  index_live_stream_viewers_on_user_id             (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (live_stream_id => live_streams.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :live_stream_viewer do
    association :live_stream
    association :site
    association :user
    joined_at { Time.current }

    trait :active do
      left_at { nil }
      duration_seconds { nil }
    end

    trait :completed do
      left_at { 30.minutes.from_now }
      duration_seconds { 1800 }
    end

    trait :anonymous do
      user { nil }
      session_id { SecureRandom.hex(16) }
    end
  end
end
