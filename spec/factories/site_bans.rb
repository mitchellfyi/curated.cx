# frozen_string_literal: true

# == Schema Information
#
# Table name: site_bans
#
#  id           :bigint           not null, primary key
#  banned_at    :datetime         not null
#  expires_at   :datetime
#  reason       :text
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  banned_by_id :bigint           not null
#  site_id      :bigint           not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_site_bans_on_banned_by_id      (banned_by_id)
#  index_site_bans_on_site_and_expires  (site_id,expires_at)
#  index_site_bans_on_site_id           (site_id)
#  index_site_bans_on_user_id           (user_id)
#  index_site_bans_uniqueness           (site_id,user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (banned_by_id => users.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :site_ban do
    site { nil } # Will be set in after(:build)
    user { nil } # Will be set in after(:build)
    banned_by { nil } # Will be set in after(:build)
    reason { Faker::Lorem.sentence }
    banned_at { Time.current }
    expires_at { nil }

    after(:build) do |site_ban|
      # Ensure users are persisted so user_id != banned_by_id validation works
      ActsAsTenant.without_tenant do
        site_ban.site ||= create(:site)
        site_ban.user ||= create(:user)
        site_ban.banned_by ||= create(:user)
      end
    end

    trait :temporary do
      expires_at { 1.week.from_now }
    end

    trait :expired do
      expires_at { 1.day.ago }
    end

    trait :permanent do
      expires_at { nil }
    end
  end
end
