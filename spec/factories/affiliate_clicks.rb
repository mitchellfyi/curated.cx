# frozen_string_literal: true

# == Schema Information
#
# Table name: affiliate_clicks
#
#  id         :bigint           not null, primary key
#  clicked_at :datetime         not null
#  ip_hash    :string
#  referrer   :text
#  user_agent :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  listing_id :bigint           not null
#
# Indexes
#
#  index_affiliate_clicks_on_clicked_at       (clicked_at)
#  index_affiliate_clicks_on_listing_clicked  (listing_id,clicked_at)
#  index_affiliate_clicks_on_listing_id       (listing_id)
#
# Foreign Keys
#
#  fk_rails_...  (listing_id => listings.id)
#
FactoryBot.define do
  factory :affiliate_click do
    listing
    clicked_at { Time.current }
    ip_hash { Digest::SHA256.hexdigest("192.168.1.#{rand(1..255)}")[0..15] }
    user_agent { "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)" }
    referrer { Faker::Internet.url }

    trait :from_google do
      referrer { "https://www.google.com/search?q=example" }
    end

    trait :from_twitter do
      referrer { "https://t.co/abc123" }
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

    trait :last_month do
      clicked_at { 1.month.ago }
    end
  end
end
