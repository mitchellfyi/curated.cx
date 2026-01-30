# frozen_string_literal: true

# == Schema Information
#
# Table name: boost_payouts
#
#  id                :bigint           not null, primary key
#  amount            :decimal(10, 2)   not null
#  paid_at           :datetime
#  payment_reference :string
#  period_end        :date             not null
#  period_start      :date             not null
#  status            :integer          default("pending"), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  site_id           :bigint           not null
#
FactoryBot.define do
  factory :boost_payout do
    association :site
    amount { 50.00 }
    period_start { 1.month.ago.beginning_of_month.to_date }
    period_end { 1.month.ago.end_of_month.to_date }
    status { :pending }

    trait :pending do
      status { :pending }
    end

    trait :paid do
      status { :paid }
      paid_at { Time.current }
      payment_reference { "PAY-#{SecureRandom.hex(8).upcase}" }
    end

    trait :cancelled do
      status { :cancelled }
    end

    trait :current_month do
      period_start { Time.current.beginning_of_month.to_date }
      period_end { Time.current.end_of_month.to_date }
    end

    trait :last_month do
      period_start { 1.month.ago.beginning_of_month.to_date }
      period_end { 1.month.ago.end_of_month.to_date }
    end
  end
end
