# == Schema Information
#
# Table name: roles
#
#  id            :bigint           not null, primary key
#  name          :string
#  resource_type :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  resource_id   :bigint
#
# Indexes
#
#  index_roles_on_name_and_resource_type_and_resource_id  (name,resource_type,resource_id)
#  index_roles_on_resource                                (resource_type,resource_id)
#
FactoryBot.define do
  factory :role do
    name { %w[owner admin editor viewer].sample }
    resource_type { "Tenant" }
    association :resource, factory: :tenant

    trait :owner do
      name { "owner" }
    end

    trait :admin do
      name { "admin" }
    end

    trait :editor do
      name { "editor" }
    end

    trait :viewer do
      name { "viewer" }
    end

    trait :global do
      resource_type { nil }
      resource { nil }
    end
  end
end
