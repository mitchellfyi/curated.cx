# frozen_string_literal: true

# == Schema Information
#
# Table name: domains
#
#  id              :bigint           not null, primary key
#  hostname        :string           not null
#  last_checked_at :datetime
#  last_error      :text
#  primary         :boolean          default(FALSE), not null
#  status          :integer          default("pending_dns"), not null
#  verified        :boolean          default(FALSE), not null
#  verified_at     :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  site_id         :bigint           not null
#
# Indexes
#
#  index_domains_on_hostname               (hostname) UNIQUE
#  index_domains_on_site_id                (site_id)
#  index_domains_on_site_id_and_verified   (site_id,verified)
#  index_domains_on_site_id_where_primary  (site_id) UNIQUE WHERE ("primary" = true)
#  index_domains_on_status                 (status)
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#
FactoryBot.define do
  factory :domain do
    association :site
    sequence(:hostname) { |n| "domain#{n}.example.com" }
    verified { false }
    primary { false }
    status { :pending_dns }
    last_checked_at { nil }
    last_error { nil }

    trait :primary do
      primary { true }
    end

    trait :verified do
      verified { true }
      verified_at { Time.current }
      status { :verified_dns }
    end

    trait :unverified do
      verified { false }
      verified_at { nil }
      status { :pending_dns }
    end

    trait :pending_dns do
      status { :pending_dns }
    end

    trait :verified_dns do
      status { :verified_dns }
      verified { true }
      verified_at { Time.current }
    end

    trait :active do
      status { :active }
      verified { true }
      verified_at { Time.current }
    end

    trait :failed do
      status { :failed }
      last_error { "DNS resolution failed" }
      last_checked_at { Time.current }
    end
  end
end
