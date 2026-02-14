# frozen_string_literal: true

# == Schema Information
#
# Table name: business_claims
#
#  id                  :bigint           not null, primary key
#  status              :string           default("pending"), not null
#  verification_code   :string
#  verification_method :string
#  verified_at         :datetime
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  entry_id            :bigint           not null
#  user_id             :bigint           not null
#
class BusinessClaim < ApplicationRecord
  STATUSES = %w[pending verified rejected].freeze
  VERIFICATION_METHODS = %w[email phone document].freeze

  belongs_to :entry
  belongs_to :user

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :verification_method, inclusion: { in: VERIFICATION_METHODS }, allow_blank: true
  validates :entry_id, uniqueness: { scope: :user_id, message: "has already been claimed by this user" }

  scope :pending, -> { where(status: "pending") }
  scope :verified, -> { where(status: "verified") }
  scope :rejected, -> { where(status: "rejected") }
  scope :recent, -> { order(created_at: :desc) }

  def pending?
    status == "pending"
  end

  def verified?
    status == "verified"
  end

  def rejected?
    status == "rejected"
  end

  def verify!
    update!(status: "verified", verified_at: Time.current)
  end

  def reject!
    update!(status: "rejected")
  end
end
