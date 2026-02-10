# frozen_string_literal: true

# == Schema Information
#
# Table name: submissions
#
#  id             :bigint           not null, primary key
#  description    :text
#  ip_address     :string
#  listing_type   :integer          default("tool"), not null
#  reviewed_at    :datetime
#  reviewer_notes :text
#  status         :integer          default("pending"), not null
#  title          :string           not null
#  url            :text             not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  category_id    :bigint           not null
#  entry_id       :bigint
#  reviewed_by_id :bigint
#  site_id        :bigint           not null
#  user_id        :bigint           not null
#
# Indexes
#
#  index_submissions_on_category_id         (category_id)
#  index_submissions_on_entry_id            (entry_id)
#  index_submissions_on_reviewed_by_id      (reviewed_by_id)
#  index_submissions_on_site_id             (site_id)
#  index_submissions_on_site_id_and_status  (site_id,status)
#  index_submissions_on_status              (status)
#  index_submissions_on_user_id             (user_id)
#  index_submissions_on_user_id_and_status  (user_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (category_id => categories.id)
#  fk_rails_...  (entry_id => entries.id)
#  fk_rails_...  (reviewed_by_id => users.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :submission do
    user
    site
    category { association :category, site: site, tenant: site.tenant }
    url { Faker::Internet.url }
    title { Faker::Lorem.sentence(word_count: 4) }
    description { Faker::Lorem.paragraph }
    listing_type { :tool }
    status { :pending }
    ip_address { Faker::Internet.ip_v4_address }

    trait :pending do
      status { :pending }
    end

    trait :approved do
      status { :approved }
      reviewed_at { Time.current }
      reviewed_by_id { association(:user).id }
    end

    trait :rejected do
      status { :rejected }
      reviewed_at { Time.current }
      reviewer_notes { "Does not meet our guidelines." }
      reviewed_by_id { association(:user).id }
    end

    trait :job do
      listing_type { :job }
    end

    trait :service do
      listing_type { :service }
    end
  end
end
