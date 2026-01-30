# frozen_string_literal: true

# == Schema Information
#
# Table name: content_views
#
#  id              :bigint           not null, primary key
#  viewed_at       :datetime         not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  content_item_id :bigint           not null
#  site_id         :bigint           not null
#  user_id         :bigint           not null
#
# Indexes
#
#  index_content_views_on_content_item_id      (content_item_id)
#  index_content_views_on_site_id              (site_id)
#  index_content_views_on_user_id              (user_id)
#  index_content_views_on_user_site_viewed_at  (user_id,site_id,viewed_at DESC)
#  index_content_views_uniqueness              (site_id,user_id,content_item_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (content_item_id => content_items.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :content_view do
    association :content_item
    association :user
    site { content_item.site }
    viewed_at { Time.current }

    trait :recent do
      viewed_at { 1.hour.ago }
    end

    trait :old do
      viewed_at { 30.days.ago }
    end
  end
end
