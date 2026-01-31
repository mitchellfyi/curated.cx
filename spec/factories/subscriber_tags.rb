# frozen_string_literal: true

# == Schema Information
#
# Table name: subscriber_tags
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  slug       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  site_id    :bigint           not null
#  tenant_id  :bigint           not null
#
# Indexes
#
#  index_subscriber_tags_on_site_id           (site_id)
#  index_subscriber_tags_on_site_id_and_slug  (site_id,slug) UNIQUE
#  index_subscriber_tags_on_tenant_id         (tenant_id)
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
FactoryBot.define do
  factory :subscriber_tag do
    sequence(:name) { |n| "Tag #{n}" }
    site
    tenant { site.tenant }

    trait :vip do
      name { "VIP" }
      slug { "vip" }
    end

    trait :beta do
      name { "Beta" }
      slug { "beta" }
    end
  end
end
