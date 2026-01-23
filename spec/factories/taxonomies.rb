# frozen_string_literal: true

# == Schema Information
#
# Table name: taxonomies
#
#  id          :bigint           not null, primary key
#  description :text
#  name        :string           not null
#  position    :integer          default(0), not null
#  slug        :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  parent_id   :bigint
#  site_id     :bigint           not null
#  tenant_id   :bigint           not null
#
# Indexes
#
#  index_taxonomies_on_site_id                (site_id)
#  index_taxonomies_on_site_id_and_parent_id  (site_id,parent_id)
#  index_taxonomies_on_site_id_and_slug       (site_id,slug) UNIQUE
#  index_taxonomies_on_tenant_id              (tenant_id)
#
# Foreign Keys
#
#  fk_rails_...  (parent_id => taxonomies.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
FactoryBot.define do
  factory :taxonomy do
    association :site
    # tenant is set from site in callback
    sequence(:name) { |n| "Taxonomy #{n}" }
    sequence(:slug) { |n| "taxonomy-#{n}" }
    description { Faker::Lorem.sentence }
    position { 0 }

    trait :with_parent do
      association :parent, factory: :taxonomy
      site { parent.site }
    end

    trait :with_children do
      after(:create) do |taxonomy|
        ActsAsTenant.without_tenant do
          create_list(:taxonomy, 2, parent: taxonomy, site: taxonomy.site)
        end
      end
    end

    trait :with_tagging_rules do
      after(:create) do |taxonomy|
        ActsAsTenant.without_tenant do
          create_list(:tagging_rule, 2, taxonomy: taxonomy, site: taxonomy.site)
        end
      end
    end
  end
end
