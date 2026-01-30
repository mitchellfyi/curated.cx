# frozen_string_literal: true

# == Schema Information
#
# Table name: boost_impressions
#
#  id               :bigint           not null, primary key
#  ip_hash          :string
#  shown_at         :datetime         not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  network_boost_id :bigint           not null
#  site_id          :bigint           not null
#
# Indexes
#
#  index_boost_impressions_on_network_boost_id               (network_boost_id)
#  index_boost_impressions_on_network_boost_id_and_shown_at  (network_boost_id,shown_at)
#  index_boost_impressions_on_site_id                        (site_id)
#  index_boost_impressions_on_site_id_and_shown_at           (site_id,shown_at)
#
# Foreign Keys
#
#  fk_rails_...  (network_boost_id => network_boosts.id)
#  fk_rails_...  (site_id => sites.id)
#
FactoryBot.define do
  factory :boost_impression do
    association :network_boost
    association :site
    shown_at { Time.current }
    ip_hash { Digest::SHA256.hexdigest("192.168.1.#{rand(1..255)}") }

    trait :today do
      shown_at { Time.current }
    end

    trait :yesterday do
      shown_at { 1.day.ago }
    end

    trait :last_week do
      shown_at { 1.week.ago }
    end

    trait :last_month do
      shown_at { 1.month.ago }
    end
  end
end
