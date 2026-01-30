# frozen_string_literal: true

# == Schema Information
#
# Table name: email_steps
#
#  id                :bigint           not null, primary key
#  body_html         :text             not null
#  body_text         :text
#  delay_seconds     :integer          default(0), not null
#  position          :integer          default(0), not null
#  subject           :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  email_sequence_id :bigint           not null
#
# Indexes
#
#  index_email_steps_on_email_sequence_id               (email_sequence_id)
#  index_email_steps_on_email_sequence_id_and_position  (email_sequence_id,position) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (email_sequence_id => email_sequences.id)
#
FactoryBot.define do
  factory :email_step do
    email_sequence
    sequence(:position) { |n| n }
    delay_seconds { 0 }
    subject { "Welcome to our newsletter" }
    body_html { "<p>Thank you for subscribing!</p>" }
    body_text { "Thank you for subscribing!" }

    trait :with_delay do
      delay_seconds { 86_400 } # 1 day
    end

    trait :one_day_delay do
      delay_seconds { 86_400 }
    end

    trait :three_day_delay do
      delay_seconds { 259_200 }
    end

    trait :one_week_delay do
      delay_seconds { 604_800 }
    end
  end
end
