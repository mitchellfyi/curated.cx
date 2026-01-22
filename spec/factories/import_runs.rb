# frozen_string_literal: true

# == Schema Information
#
# Table name: import_runs
#
#  id            :bigint           not null, primary key
#  completed_at  :datetime
#  error_message :text
#  items_count   :integer          default(0)
#  items_created :integer          default(0)
#  items_failed  :integer          default(0)
#  items_updated :integer          default(0)
#  started_at    :datetime         not null
#  status        :integer          default("running"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  site_id       :bigint           not null
#  source_id     :bigint           not null
#
# Indexes
#
#  index_import_runs_on_site_id                   (site_id)
#  index_import_runs_on_site_id_and_started_at    (site_id,started_at)
#  index_import_runs_on_source_id                 (source_id)
#  index_import_runs_on_source_id_and_started_at  (source_id,started_at)
#  index_import_runs_on_status                    (status)
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (source_id => sources.id)
#
FactoryBot.define do
  factory :import_run do
    association :source
    site { source.site }
    started_at { Time.current }
    status { :running }
    items_count { 0 }
    items_created { 0 }
    items_updated { 0 }
    items_failed { 0 }

    trait :completed do
      status { :completed }
      completed_at { Time.current }
      items_count { 10 }
      items_created { 8 }
      items_updated { 2 }
      items_failed { 0 }
    end

    trait :failed do
      status { :failed }
      completed_at { Time.current }
      error_message { "Import failed: Connection timeout" }
    end
  end
end
