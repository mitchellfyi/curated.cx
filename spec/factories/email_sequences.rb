# frozen_string_literal: true

# == Schema Information
#
# Table name: email_sequences
#
#  id             :bigint           not null, primary key
#  enabled        :boolean          default(FALSE), not null
#  name           :string           not null
#  trigger_config :jsonb
#  trigger_type   :integer          default("subscriber_joined"), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  site_id        :bigint           not null
#
# Indexes
#
#  index_email_sequences_on_site_id                               (site_id)
#  index_email_sequences_on_site_id_and_trigger_type_and_enabled  (site_id,trigger_type,enabled)
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#
FactoryBot.define do
  factory :email_sequence do
    site
    sequence(:name) { |n| "Welcome Sequence #{n}" }
    trigger_type { :subscriber_joined }
    trigger_config { {} }
    enabled { false }

    trait :enabled do
      enabled { true }
    end

    trait :referral_milestone_trigger do
      trigger_type { :referral_milestone }
      trigger_config { { milestone: 3 } }
    end

    trait :with_steps do
      after(:create) do |sequence|
        create(:email_step, email_sequence: sequence, position: 0, delay_seconds: 0,
               subject: "Welcome!", body_html: "<p>Welcome to our newsletter!</p>")
        create(:email_step, email_sequence: sequence, position: 1, delay_seconds: 86_400,
               subject: "Getting Started", body_html: "<p>Here's how to get started...</p>")
        create(:email_step, email_sequence: sequence, position: 2, delay_seconds: 259_200,
               subject: "Did you know?", body_html: "<p>Here are some tips...</p>")
      end
    end
  end
end
