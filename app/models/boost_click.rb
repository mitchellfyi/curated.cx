# frozen_string_literal: true

# == Schema Information
#
# Table name: boost_clicks
#
#  id                     :bigint           not null, primary key
#  clicked_at             :datetime         not null
#  converted_at           :datetime
#  earned_amount          :decimal(8, 2)
#  ip_hash                :string
#  status                 :integer          default("pending"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  digest_subscription_id :bigint
#  network_boost_id       :bigint           not null
#
# Indexes
#
#  index_boost_clicks_on_digest_subscription_id           (digest_subscription_id)
#  index_boost_clicks_on_ip_hash_and_clicked_at           (ip_hash,clicked_at)
#  index_boost_clicks_on_network_boost_id                 (network_boost_id)
#  index_boost_clicks_on_network_boost_id_and_clicked_at  (network_boost_id,clicked_at)
#  index_boost_clicks_on_status                           (status)
#
# Foreign Keys
#
#  fk_rails_...  (digest_subscription_id => digest_subscriptions.id)
#  fk_rails_...  (network_boost_id => network_boosts.id)
#
class BoostClick < ApplicationRecord
  # Associations
  belongs_to :network_boost
  belongs_to :digest_subscription, optional: true

  # Enums
  enum :status, { pending: 0, confirmed: 1, paid: 2, cancelled: 3 }, default: :pending

  # Validations
  validates :clicked_at, presence: true
  validates :earned_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Scopes
  scope :recent, -> { order(clicked_at: :desc) }
  scope :today, -> { where(clicked_at: Time.current.beginning_of_day..) }
  scope :this_week, -> { where(clicked_at: 1.week.ago..) }
  scope :this_month, -> { where(clicked_at: 1.month.ago..) }
  scope :converted, -> { where.not(converted_at: nil) }
  scope :unconverted, -> { where(converted_at: nil) }
  scope :for_boost, ->(boost) { where(network_boost: boost) }
  scope :within_attribution_window, ->(ip_hash) {
    where(ip_hash: ip_hash, clicked_at: 30.days.ago.., converted_at: nil)
  }

  # Confirm the click (called after 24h verification)
  def confirm!
    return false unless pending?

    update!(status: :confirmed)
    true
  end

  # Mark as paid
  def mark_paid!
    return false unless confirmed?

    update!(status: :paid)
    true
  end

  # Cancel the click (e.g., fraud detected)
  def cancel!
    return false if paid?

    update!(status: :cancelled)
    true
  end

  # Mark as converted with subscription
  def mark_converted!(subscription)
    return false if converted_at.present?

    update!(
      converted_at: Time.current,
      digest_subscription: subscription
    )
    true
  end

  # Helper to get the target site
  delegate :target_site, to: :network_boost

  # Helper to get the source site
  delegate :source_site, to: :network_boost

  # Class methods for analytics
  def self.count_for_boost(boost_id, since: 30.days.ago)
    where(network_boost_id: boost_id, clicked_at: since..).count
  end

  def self.conversion_rate(boost_id, since: 30.days.ago)
    total = count_for_boost(boost_id, since: since)
    return 0.0 if total.zero?

    converted = where(network_boost_id: boost_id, clicked_at: since..)
                .where.not(converted_at: nil)
                .count
    (converted.to_f / total * 100).round(2)
  end
end
