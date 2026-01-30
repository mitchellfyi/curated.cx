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
# Indexes
#
#  index_boost_payouts_on_site_id                   (site_id)
#  index_boost_payouts_on_site_id_and_period_start  (site_id,period_start)
#  index_boost_payouts_on_status                    (status)
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#
class BoostPayout < ApplicationRecord
  # Associations
  belongs_to :site

  # Enums
  enum :status, { pending: 0, paid: 1, cancelled: 2 }, default: :pending

  # Validations
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :period_start, presence: true
  validates :period_end, presence: true
  validate :period_end_after_start

  # Scopes
  scope :recent, -> { order(period_start: :desc) }
  scope :for_site, ->(site) { where(site: site) }
  scope :for_period, ->(start_date, end_date) {
    where(period_start: start_date, period_end: end_date)
  }

  # Mark as paid
  def mark_paid!(reference = nil)
    return false unless pending?

    update!(
      status: :paid,
      paid_at: Time.current,
      payment_reference: reference
    )
    true
  end

  # Cancel the payout
  def cancel!
    return false if paid?

    update!(status: :cancelled)
    true
  end

  # Helper for formatted period
  def period_description
    "#{period_start.strftime('%b %Y')}"
  end

  # Class method to calculate earnings for a site in a period
  def self.calculate_earnings(site:, start_date:, end_date:)
    # Sum confirmed clicks where this site is the SOURCE (they earn from promoting others)
    BoostClick
      .joins(:network_boost)
      .where(network_boosts: { source_site_id: site.id })
      .where(status: [ :confirmed, :paid ])
      .where(clicked_at: start_date..end_date)
      .sum(:earned_amount)
  end

  # Class method to create a payout for a period
  def self.create_for_period!(site:, start_date:, end_date:)
    amount = calculate_earnings(site: site, start_date: start_date, end_date: end_date)
    return nil if amount.zero?

    create!(
      site: site,
      amount: amount,
      period_start: start_date,
      period_end: end_date
    )
  end

  private

  def period_end_after_start
    return if period_start.blank? || period_end.blank?

    if period_end < period_start
      errors.add(:period_end, "must be after period start")
    end
  end
end
