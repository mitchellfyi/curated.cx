# frozen_string_literal: true

# == Schema Information
#
# Table name: tenant_invitations
#
#  id            :bigint           not null, primary key
#  accepted_at   :datetime
#  email         :string           not null
#  expires_at    :datetime         not null
#  role          :string           default("viewer"), not null
#  token         :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  invited_by_id :bigint           not null
#  tenant_id     :bigint           not null
#
# Indexes
#
#  index_tenant_invitations_on_invited_by_id        (invited_by_id)
#  index_tenant_invitations_on_tenant_id            (tenant_id)
#  index_tenant_invitations_on_tenant_id_and_email  (tenant_id,email) UNIQUE WHERE (accepted_at IS NULL)
#  index_tenant_invitations_on_token                (token) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (invited_by_id => users.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
FactoryBot.define do
  factory :tenant_invitation do
    association :tenant
    association :invited_by, factory: :user
    email { Faker::Internet.email }
    role { "editor" }
    expires_at { 7.days.from_now }

    trait :expired do
      expires_at { 1.day.ago }
    end

    trait :accepted do
      accepted_at { 1.day.ago }
    end
  end
end
