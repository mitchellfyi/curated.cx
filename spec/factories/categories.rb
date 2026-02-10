# == Schema Information
#
# Table name: categories
#
#  id               :bigint           not null, primary key
#  allow_paths      :boolean          default(TRUE), not null
#  category_type    :string           default("article"), not null
#  display_template :string
#  key              :string           not null
#  metadata_schema  :jsonb            not null
#  name             :string           not null
#  shown_fields     :jsonb            not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  site_id          :bigint           not null
#  tenant_id        :bigint           not null
#
# Indexes
#
#  index_categories_on_site_id                    (site_id)
#  index_categories_on_site_id_and_category_type  (site_id,category_type)
#  index_categories_on_site_id_and_key            (site_id,key) UNIQUE
#  index_categories_on_site_id_and_name           (site_id,name)
#  index_categories_on_tenant_id                  (tenant_id)
#  index_categories_on_tenant_id_and_key          (tenant_id,key) UNIQUE
#  index_categories_on_tenant_name                (tenant_id,name)
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
FactoryBot.define do
  factory :category do
    tenant
    site { Current.site || tenant&.sites&.first || association(:site, tenant: tenant) }
    sequence(:key) { |n| "category_#{n}" }
    sequence(:name) { |n| "Category #{n}" }
    allow_paths { true }
    category_type { "article" }
    shown_fields do
      {
        title: true,
        description: true,
        image_url: true,
        site_name: true,
        published_at: true,
        ai_summary: false
      }
    end

    trait :news do
      key { 'news' }
      name { 'News' }
      allow_paths { true }
      category_type { "article" }
    end

    trait :apps do
      key { 'apps' }
      name { 'Apps & Tools' }
      allow_paths { false }
      category_type { "resource" }
    end

    trait :services do
      key { 'services' }
      name { 'Services' }
      allow_paths { false }
      category_type { "service" }
    end

    trait :root_domain_only do
      allow_paths { false }
    end

    trait :product do
      category_type { "product" }
      display_template { "grid" }
    end

    trait :event do
      category_type { "event" }
      display_template { "calendar" }
    end

    trait :job do
      category_type { "job" }
    end

    trait :media do
      category_type { "media" }
      display_template { "grid" }
    end

    trait :discussion do
      category_type { "discussion" }
    end

    trait :resource do
      category_type { "resource" }
      display_template { "grid" }
    end
  end
end
