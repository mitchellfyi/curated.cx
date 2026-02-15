# frozen_string_literal: true

# == Schema Information
#
# Table name: business_subscriptions
#
#  id                     :bigint           not null, primary key
#  current_period_end     :datetime
#  current_period_start   :datetime
#  status                 :string           default("active"), not null
#  tier                   :string           not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  entry_id               :bigint           not null
#  stripe_subscription_id :string
#  user_id                :bigint           not null
#
class BusinessSubscription < ApplicationRecord
  TIERS = %w[pro premium].freeze
  STATUSES = %w[active past_due cancelled].freeze

  belongs_to :entry
  belongs_to :user

  validates :tier, presence: true, inclusion: { in: TIERS }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :stripe_subscription_id, uniqueness: true, allow_nil: true

  scope :active, -> { where(status: "active") }
  scope :cancelled, -> { where(status: "cancelled") }
  scope :pro, -> { where(tier: "pro") }
  scope :premium, -> { where(tier: "premium") }
  scope :recent, -> { order(created_at: :desc) }
  scope :expiring_soon, -> { active.where("current_period_end <= ?", 7.days.from_now) }

  def active?
    status == "active"
  end

  def cancelled?
    status == "cancelled"
  end

  def pro?
    tier == "pro"
  end

  def premium?
    tier == "premium"
  end

  def cancel!
    update!(status: "cancelled")
  end

  def current_period?
    return false unless current_period_start && current_period_end

    Time.current.between?(current_period_start, current_period_end)
  end
end
