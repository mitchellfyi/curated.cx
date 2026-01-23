# frozen_string_literal: true

# == Schema Information
#
# Table name: comments
#
#  id              :bigint           not null, primary key
#  body            :text             not null
#  edited_at       :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  content_item_id :bigint           not null
#  parent_id       :bigint
#  site_id         :bigint           not null
#  user_id         :bigint           not null
#
# Indexes
#
#  index_comments_on_content_item_and_parent  (content_item_id,parent_id)
#  index_comments_on_content_item_id          (content_item_id)
#  index_comments_on_parent_id                (parent_id)
#  index_comments_on_site_and_user            (site_id,user_id)
#  index_comments_on_site_id                  (site_id)
#  index_comments_on_user_id                  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (content_item_id => content_items.id)
#  fk_rails_...  (parent_id => comments.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :comment do
    association :content_item
    association :user
    site { content_item.site }
    body { Faker::Lorem.paragraph }
    parent { nil }

    trait :reply do
      transient do
        parent_comment { nil }
      end

      parent { parent_comment || association(:comment, content_item: content_item, site: site) }
    end

    trait :edited do
      edited_at { 1.hour.ago }
    end

    trait :long do
      body { Faker::Lorem.paragraphs(number: 10).join("\n\n") }
    end
  end
end
