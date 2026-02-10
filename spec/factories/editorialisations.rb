# frozen_string_literal: true

# == Schema Information
#
# Table name: editorialisations
#
#  id                   :bigint           not null, primary key
#  ai_model             :string
#  duration_ms          :integer
#  error_message        :text
#  estimated_cost_cents :integer
#  input_tokens         :integer
#  output_tokens        :integer
#  parsed_response      :jsonb            not null
#  prompt_text          :text             not null
#  prompt_version       :string           not null
#  raw_response         :text
#  status               :integer          default("pending"), not null
#  tokens_used          :integer
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  entry_id             :bigint           not null
#  site_id              :bigint           not null
#
# Indexes
#
#  index_editorialisations_cost_tracking              (site_id,created_at,estimated_cost_cents)
#  index_editorialisations_on_entry_id                (entry_id)
#  index_editorialisations_on_site_id                 (site_id)
#  index_editorialisations_on_site_id_and_created_at  (site_id,created_at)
#  index_editorialisations_on_site_id_and_status      (site_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (entry_id => entries.id)
#  fk_rails_...  (site_id => sites.id)
#
FactoryBot.define do
  factory :editorialisation do
    association :entry, :feed
    site { entry.site }
    prompt_version { "v1.0.0" }
    prompt_text { "Analyze the following article..." }
    status { :pending }

    trait :pending do
      status { :pending }
    end

    trait :processing do
      status { :processing }
    end

    trait :completed do
      status { :completed }
      raw_response { { "summary" => "Test summary", "why_it_matters" => "Test context", "suggested_tags" => %w[tech ai] }.to_json }
      parsed_response do
        {
          "summary" => "This is a test summary of the article.",
          "why_it_matters" => "This matters because it demonstrates AI capabilities.",
          "suggested_tags" => %w[technology artificial-intelligence]
        }
      end
      tokens_used { 150 }
      input_tokens { 100 }
      output_tokens { 50 }
      estimated_cost_cents { 2 }
      duration_ms { 1500 }
      ai_model { "gpt-4o-mini" }
    end

    trait :failed do
      status { :failed }
      error_message { "API request failed: 500 Internal Server Error" }
    end

    trait :skipped do
      status { :skipped }
      prompt_text { "(skipped)" }
      error_message { "Insufficient text (50 chars, minimum 200)" }
    end
  end
end
