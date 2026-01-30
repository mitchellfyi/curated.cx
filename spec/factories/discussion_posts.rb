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
