# frozen_string_literal: true

# == Schema Information
#
# Table name: sequence_enrollments
#
#  id                     :bigint           not null, primary key
#  completed_at           :datetime
#  current_step_position  :integer          default(0), not null
#  enrolled_at            :datetime         not null
#  status                 :integer          default("active"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  digest_subscription_id :bigint           not null
#  email_sequence_id      :bigint           not null
#
# Indexes
#
#  idx_enrollments_sequence_subscription                 (email_sequence_id,digest_subscription_id) UNIQUE
#  index_sequence_enrollments_on_digest_subscription_id  (digest_subscription_id)
#  index_sequence_enrollments_on_email_sequence_id       (email_sequence_id)
#  index_sequence_enrollments_on_status                  (status)
#
# Foreign Keys
#
#  fk_rails_...  (digest_subscription_id => digest_subscriptions.id)
#  fk_rails_...  (email_sequence_id => email_sequences.id)
#
FactoryBot.define do
  factory :sequence_enrollment do
    email_sequence
    digest_subscription
    status { :active }
    current_step_position { 0 }
    enrolled_at { Time.current }

    trait :completed do
      status { :completed }
      completed_at { Time.current }
    end

    trait :stopped do
      status { :stopped }
    end

    trait :in_progress do
      current_step_position { 1 }
    end
  end
end
