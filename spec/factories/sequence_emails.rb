# frozen_string_literal: true

# == Schema Information
#
# Table name: sequence_emails
#
#  id                     :bigint           not null, primary key
#  scheduled_for          :datetime         not null
#  sent_at                :datetime
#  status                 :integer          default("pending"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  email_step_id          :bigint           not null
#  sequence_enrollment_id :bigint           not null
#
# Indexes
#
#  index_sequence_emails_on_email_step_id             (email_step_id)
#  index_sequence_emails_on_sequence_enrollment_id    (sequence_enrollment_id)
#  index_sequence_emails_on_status_and_scheduled_for  (status,scheduled_for)
#
# Foreign Keys
#
#  fk_rails_...  (email_step_id => email_steps.id)
#  fk_rails_...  (sequence_enrollment_id => sequence_enrollments.id)
#
FactoryBot.define do
  factory :sequence_email do
    sequence_enrollment
    email_step
    status { :pending }
    scheduled_for { Time.current }

    trait :sent do
      status { :sent }
      sent_at { Time.current }
    end

    trait :failed do
      status { :failed }
    end

    trait :due do
      scheduled_for { 1.minute.ago }
    end

    trait :future do
      scheduled_for { 1.day.from_now }
    end
  end
end
