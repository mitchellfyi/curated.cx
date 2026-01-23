# frozen_string_literal: true

FactoryBot.define do
  factory :editorialisation do
    association :content_item
    site { content_item.site }
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
      duration_ms { 1500 }
      model_name { "gpt-4o-mini" }
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
