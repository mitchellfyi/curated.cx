# frozen_string_literal: true

# == Schema Information
#
# Table name: live_streams
#
#  id                 :bigint           not null, primary key
#  description        :text
#  ended_at           :datetime
#  peak_viewers       :integer          default(0), not null
#  scheduled_at       :datetime         not null
#  started_at         :datetime
#  status             :integer          default("scheduled"), not null
#  stream_key         :string
#  title              :string           not null
#  viewer_count       :integer          default(0), not null
#  visibility         :integer          default("public_access"), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  discussion_id      :bigint
#  mux_asset_id       :string
#  mux_playback_id    :string
#  mux_stream_id      :string
#  replay_playback_id :string
#  site_id            :bigint           not null
#  user_id            :bigint           not null
#
# Indexes
#
#  index_live_streams_on_discussion_id             (discussion_id)
#  index_live_streams_on_mux_stream_id             (mux_stream_id) UNIQUE
#  index_live_streams_on_site_id                   (site_id)
#  index_live_streams_on_site_id_and_scheduled_at  (site_id,scheduled_at)
#  index_live_streams_on_site_id_and_status        (site_id,status)
#  index_live_streams_on_user_id                   (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (discussion_id => discussions.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :live_stream do
    association :user
    association :site
    title { Faker::Lorem.sentence(word_count: 5) }
    description { Faker::Lorem.paragraph }
    scheduled_at { 1.hour.from_now }
    status { :scheduled }
    visibility { :public_access }

    trait :scheduled do
      status { :scheduled }
      scheduled_at { 1.hour.from_now }
      started_at { nil }
      ended_at { nil }
    end

    trait :live do
      status { :live }
      scheduled_at { 1.hour.ago }
      started_at { 30.minutes.ago }
      ended_at { nil }
    end

    trait :ended do
      status { :ended }
      scheduled_at { 2.hours.ago }
      started_at { 1.hour.ago }
      ended_at { 30.minutes.ago }
    end

    trait :archived do
      status { :archived }
      scheduled_at { 1.day.ago }
      started_at { 1.day.ago }
      ended_at { 1.day.ago + 1.hour }
    end

    trait :with_mux do
      mux_stream_id { "live-stream-#{SecureRandom.hex(8)}" }
      mux_playback_id { "playback-#{SecureRandom.hex(8)}" }
      stream_key { "stream-key-#{SecureRandom.hex(16)}" }
    end

    trait :with_replay do
      ended
      mux_asset_id { "asset-#{SecureRandom.hex(8)}" }
      replay_playback_id { "replay-#{SecureRandom.hex(8)}" }
    end

    trait :subscribers_only do
      visibility { :subscribers_only }
    end

    trait :with_discussion do
      after(:create) do |live_stream|
        live_stream.update!(
          discussion: create(:discussion, site: live_stream.site, user: live_stream.user)
        )
      end
    end

    trait :with_viewers do
      transient do
        viewer_count_override { 5 }
      end

      after(:create) do |live_stream, evaluator|
        create_list(:live_stream_viewer, evaluator.viewer_count_override,
                    live_stream: live_stream,
                    site: live_stream.site)
      end
    end
  end
end
