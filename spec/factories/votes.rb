# frozen_string_literal: true

# == Schema Information
#
# Table name: votes
#
#  id              :bigint           not null, primary key
#  value           :integer          default(1), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  content_item_id :bigint           not null
#  site_id         :bigint           not null
#  user_id         :bigint           not null
#
# Indexes
#
#  index_votes_on_content_item_id  (content_item_id)
#  index_votes_on_site_id          (site_id)
#  index_votes_on_user_id          (user_id)
#  index_votes_uniqueness          (site_id,user_id,content_item_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (content_item_id => content_items.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :vote do
    association :content_item
    association :user
    site { content_item.site }
    value { 1 }

    trait :downvote do
      value { -1 }
    end
  end
end
