# frozen_string_literal: true

# == Schema Information
#
# Table name: workflow_pauses
#
#  id            :bigint           not null, primary key
#  paused_at     :datetime         not null
#  reason        :text
#  resumed_at    :datetime
#  workflow_type :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  paused_by_id  :bigint           not null
#  resumed_by_id :bigint
#  source_id     :bigint
#  tenant_id     :bigint
#
# Indexes
#
#  index_workflow_pauses_active_by_type_tenant  (workflow_type,tenant_id) WHERE (resumed_at IS NULL)
#  index_workflow_pauses_active_unique          (workflow_type,tenant_id,source_id) UNIQUE WHERE (resumed_at IS NULL)
#  index_workflow_pauses_history                (workflow_type,paused_at)
#
# Foreign Keys
#
#  fk_rails_...  (paused_by_id => users.id)
#  fk_rails_...  (resumed_by_id => users.id)
#  fk_rails_...  (source_id => sources.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
FactoryBot.define do
  factory :workflow_pause do
    association :paused_by, factory: :user
    association :tenant
    workflow_type { "rss_ingestion" }
    paused_at { Time.current }
    reason { nil }
    resumed_at { nil }

    trait :global do
      tenant { nil }
    end

    trait :for_rss do
      workflow_type { "rss_ingestion" }
    end

    trait :for_serp_api do
      workflow_type { "serp_api_ingestion" }
    end

    trait :for_editorialisation do
      workflow_type { "editorialisation" }
    end

    trait :for_all_ingestion do
      workflow_type { "all_ingestion" }
    end

    trait :with_reason do
      reason { "Cost control - approaching monthly limit" }
    end

    trait :source_specific do
      association :source
      tenant { source.tenant }
    end

    trait :resolved do
      association :resumed_by, factory: :user
      resumed_at { Time.current }
    end

    trait :long_running do
      paused_at { 3.days.ago }
    end
  end
end
