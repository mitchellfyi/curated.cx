# frozen_string_literal: true

# == Schema Information
#
# Table name: flags
#
#  id             :bigint           not null, primary key
#  details        :text
#  flaggable_type :string           not null
#  reason         :integer          default("spam"), not null
#  reviewed_at    :datetime
#  status         :integer          default("pending"), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  flaggable_id   :bigint           not null
#  reviewed_by_id :bigint
#  site_id        :bigint           not null
#  user_id        :bigint           not null
#
# Indexes
#
#  index_flags_on_flaggable        (flaggable_type,flaggable_id)
#  index_flags_on_reviewed_by_id   (reviewed_by_id)
#  index_flags_on_site_and_status  (site_id,status)
#  index_flags_on_site_id          (site_id)
#  index_flags_on_user_id          (user_id)
#  index_flags_uniqueness          (site_id,user_id,flaggable_type,flaggable_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (reviewed_by_id => users.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :flag do
    association :user
    association :flaggable, factory: :entry
    site { flaggable.site }
    reason { :spam }
    status { :pending }
    details { nil }

    trait :for_entry do
      association :flaggable, factory: :entry
    end

    trait :for_comment do
      association :flaggable, factory: :comment
    end

    trait :harassment do
      reason { :harassment }
    end

    trait :misinformation do
      reason { :misinformation }
    end

    trait :inappropriate do
      reason { :inappropriate }
    end

    trait :other do
      reason { :other }
      details { Faker::Lorem.sentence }
    end

    trait :with_details do
      details { Faker::Lorem.paragraph }
    end

    trait :reviewed do
      status { :reviewed }
      association :reviewed_by, factory: :user
      reviewed_at { Time.current }
    end

    trait :dismissed do
      status { :dismissed }
      association :reviewed_by, factory: :user
      reviewed_at { Time.current }
    end

    trait :action_taken do
      status { :action_taken }
      association :reviewed_by, factory: :user
      reviewed_at { Time.current }
    end
  end
end
