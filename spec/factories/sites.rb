# frozen_string_literal: true

# == Schema Information
#
# Table name: sites
#
#  id          :bigint           not null, primary key
#  config      :jsonb            not null
#  description :text
#  name        :string           not null
#  slug        :string           not null
#  status      :integer          default("enabled"), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  tenant_id   :bigint           not null
#
# Indexes
#
#  index_sites_on_status                (status)
#  index_sites_on_tenant_id             (tenant_id)
#  index_sites_on_tenant_id_and_slug    (tenant_id,slug) UNIQUE
#  index_sites_on_tenant_id_and_status  (tenant_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (tenant_id => tenants.id)
#
FactoryBot.define do
  factory :site do
    association :tenant
    sequence(:slug) { |n| "site_#{n}" }
    name { Faker::Company.name }
    description { Faker::Lorem.paragraph }
    config do
      {
        topics: [ "technology", "business" ],
        ingestion: {
          enabled: true,
          sources: {
            serp_api: true,
            rss: true
          }
        },
        monetisation: {
          enabled: false
        }
      }
    end
    status { :enabled }

    trait :disabled do
      status { :disabled }
    end

    trait :private_access do
      status { :private_access }
    end

    trait :with_domains do
      after(:create) do |site|
        create(:domain, :primary, site: site, hostname: "#{site.slug}.example.com")
        create(:domain, site: site, hostname: "www.#{site.slug}.example.com")
      end
    end
  end
end
