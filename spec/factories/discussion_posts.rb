# frozen_string_literal: true

# == Schema Information
#
# Table name: discussion_posts
#
#  id            :bigint           not null, primary key
#  body          :text             not null
#  edited_at     :datetime
#  hidden_at     :datetime
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  discussion_id :bigint           not null
#  parent_id     :bigint
#  site_id       :bigint           not null
#  user_id       :bigint           not null
#
# Indexes
#
#  index_discussion_posts_on_discussion_id                 (discussion_id)
#  index_discussion_posts_on_discussion_id_and_created_at  (discussion_id,created_at)
#  index_discussion_posts_on_parent_id                     (parent_id)
#  index_discussion_posts_on_site_id                       (site_id)
#  index_discussion_posts_on_site_id_and_user_id           (site_id,user_id)
#  index_discussion_posts_on_user_id                       (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (discussion_id => discussions.id)
#  fk_rails_...  (parent_id => discussion_posts.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :discussion_post do
    association :discussion
    association :user
    site { discussion.site }
    body { Faker::Lorem.paragraph }
    parent { nil }

    trait :reply do
      transient do
        parent_post { nil }
      end

      parent { parent_post || association(:discussion_post, discussion: discussion, site: site) }
    end

    trait :edited do
      edited_at { 1.hour.ago }
    end

    trait :hidden do
      hidden_at { Time.current }
    end

    trait :long do
      body { Faker::Lorem.paragraphs(number: 10).join("\n\n") }
    end
  end
end
