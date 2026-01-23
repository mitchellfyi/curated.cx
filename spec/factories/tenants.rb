# frozen_string_literal: true

# == Schema Information
#
# Table name: tenants
#
#  id          :bigint           not null, primary key
#  description :text
#  hostname    :string           not null
#  logo_url    :string
#  settings    :jsonb            not null
#  slug        :string           not null
#  status      :integer          default("enabled"), not null
#  title       :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_tenants_on_hostname         (hostname) UNIQUE
#  index_tenants_on_slug             (slug) UNIQUE
#  index_tenants_on_status           (status)
#  index_tenants_on_status_hostname  (status,hostname)
#
FactoryBot.define do
  factory :tenant do
    sequence(:slug) { |n| "tenant_#{n}" }
    sequence(:hostname) { |n| "tenant#{n}.example.com" }
    title { Faker::Company.name }
    description { Faker::Lorem.paragraph }
    logo_url { Faker::Internet.url }
    settings do
      {
        theme: {
          primary_color: "blue",
          secondary_color: "gray"
        },
        categories: {
          news: { enabled: true },
          apps: { enabled: false },
          services: { enabled: false }
        }
      }
    end
    status { :enabled }

    # By default, create a site and domain so tenant hostname resolution works
    # Use ActsAsTenant.without_tenant to prevent current_tenant from overriding the tenant_id
    after(:create) do |tenant|
      ActsAsTenant.without_tenant do
        site = create(:site, tenant: tenant, slug: tenant.slug, name: tenant.title)
        create(:domain, :primary, site: site, hostname: tenant.hostname)
      end
    end

    trait :without_site do
      after(:create) { } # Override to skip site creation
    end

    trait :root do
      slug { "root" }
      hostname { "curated.cx" }
      title { "Curated.cx" }
      description { "The central hub for curated industry content" }
    end

    trait :ai_news do
      slug { "ai" }
      hostname { "ainews.cx" }
      title { "AI News" }
      description { "Curated AI industry news and insights" }
      settings do
        {
          theme: {
            primary_color: "purple",
            secondary_color: "gray"
          },
          categories: {
            news: { enabled: true },
            apps: { enabled: true },
            services: { enabled: true }
          }
        }
      end
    end

    trait :construction do
      slug { "construction" }
      hostname { "construction.cx" }
      title { "Construction News" }
      description { "Latest construction industry news and trends" }
      settings do
        {
          theme: {
            primary_color: "amber",
            secondary_color: "gray"
          },
          categories: {
            news: { enabled: true },
            apps: { enabled: true },
            services: { enabled: true }
          }
        }
      end
    end

    trait :disabled do
      status { :disabled }
    end

    trait :private_access do
      status { :private_access }
    end
  end
end
