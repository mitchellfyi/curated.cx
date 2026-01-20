# == Schema Information
#
# Table name: categories
#
#  id           :bigint           not null, primary key
#  allow_paths  :boolean          default(TRUE), not null
#  key          :string           not null
#  name         :string           not null
#  shown_fields :jsonb            not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  tenant_id    :bigint           not null
#
# Indexes
#
#  index_categories_on_tenant_id          (tenant_id)
#  index_categories_on_tenant_id_and_key  (tenant_id,key) UNIQUE
#  index_categories_on_tenant_name        (tenant_id,name)
#
# Foreign Keys
#
#  fk_rails_...  (tenant_id => tenants.id)
#
FactoryBot.define do
  factory :category do
    tenant
    sequence(:key) { |n| "category_#{n}" }
    sequence(:name) { |n| "Category #{n}" }
    allow_paths { true }
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
    end

    trait :apps do
      key { 'apps' }
      name { 'Apps & Tools' }
      allow_paths { false }
    end

    trait :services do
      key { 'services' }
      name { 'Services' }
      allow_paths { false }
    end

    trait :root_domain_only do
      allow_paths { false }
    end
  end
end
