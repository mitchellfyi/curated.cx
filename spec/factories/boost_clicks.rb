# frozen_string_literal: true

# == Schema Information
#
# Table name: boost_clicks
#
#  id                     :bigint           not null, primary key
#  clicked_at             :datetime         not null
#  converted_at           :datetime
#  earned_amount          :decimal(8, 2)
#  ip_hash                :string
#  status                 :integer          default("pending"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  digest_subscription_id :bigint
#  network_boost_id       :bigint           not null
#
FactoryBot.define do
  factory :boost_click do
    association :network_boost
    clicked_at { Time.current }
    ip_hash { Digest::SHA256.hexdigest("192.168.1.#{rand(1..255)}") }
    earned_amount { 0.50 }
    status { :pending }

    trait :pending do
      status { :pending }
    end

    trait :confirmed do
      status { :confirmed }
    end

    trait :paid do
      status { :paid }
    end

    trait :cancelled do
      status { :cancelled }
    end

    trait :converted do
      converted_at { Time.current }
      association :digest_subscription
    end

    trait :today do
      clicked_at { Time.current }
    end

    trait :yesterday do
      clicked_at { 1.day.ago }
    end

    trait :last_week do
      clicked_at { 1.week.ago }
    end

    trait :within_attribution_window do
      clicked_at { 15.days.ago }
    end

    trait :outside_attribution_window do
      clicked_at { 31.days.ago }
    end
  end
end
