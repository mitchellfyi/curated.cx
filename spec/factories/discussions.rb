# frozen_string_literal: true

# == Schema Information
#
# Table name: discussions
#
#  id           :bigint           not null, primary key
#  body         :text
#  last_post_at :datetime
#  locked_at    :datetime
#  pinned       :boolean          default(FALSE), not null
#  pinned_at    :datetime
#  posts_count  :integer          default(0), not null
#  title        :string           not null
#  visibility   :integer          default("public_access"), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  locked_by_id :bigint
#  site_id      :bigint           not null
#  user_id      :bigint           not null
#
FactoryBot.define do
  factory :discussion do
    association :user
    association :site
    title { Faker::Lorem.sentence(word_count: 5) }
    body { Faker::Lorem.paragraph }
    visibility { :public_access }
    pinned { false }

    trait :subscribers_only do
      visibility { :subscribers_only }
    end

    trait :pinned do
      pinned { true }
      pinned_at { Time.current }
    end

    trait :locked do
      locked_at { Time.current }
      association :locked_by, factory: :user
    end

    trait :with_posts do
      transient do
        posts_count_override { 3 }
      end

      after(:create) do |discussion, evaluator|
        create_list(:discussion_post, evaluator.posts_count_override, discussion: discussion, site: discussion.site)
      end
    end

    trait :with_activity do
      last_post_at { 1.hour.ago }
    end
  end
end
