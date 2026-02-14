# frozen_string_literal: true

# == Schema Information
#
# Table name: sponsorships
#
#  id             :bigint           not null, primary key
#  budget_cents   :integer          default(0), not null
#  category_slug  :string
#  clicks         :integer          default(0), not null
#  ends_at        :datetime         not null
#  impressions    :integer          default(0), not null
#  placement_type :string           not null
#  spent_cents    :integer          default(0), not null
#  starts_at      :datetime         not null
#  status         :string           default("pending"), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  entry_id       :bigint
#  site_id        :bigint           not null
#  user_id        :bigint           not null
#
class Sponsorship < ApplicationRecord
  include SiteScoped

  PLACEMENT_TYPES = %w[featured boosted category_sponsor newsletter homepage].freeze
  STATUSES = %w[pending active paused completed rejected].freeze

  belongs_to :entry, optional: true
  belongs_to :user

  validates :placement_type, presence: true, inclusion: { in: PLACEMENT_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :starts_at, presence: true
  validates :ends_at, presence: true
  validates :budget_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :spent_cents, numericality: { greater_than_or_equal_to: 0 }

  validate :ends_at_after_starts_at

  scope :active, -> { where(status: "active") }
  scope :pending, -> { where(status: "pending") }
  scope :paused, -> { where(status: "paused") }
  scope :completed, -> { where(status: "completed") }
  scope :current, -> { active.where("starts_at <= ? AND ends_at >= ?", Time.current, Time.current) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_placement, ->(type) { where(placement_type: type) }

  def active?
    status == "active"
  end

  def pending?
    status == "pending"
  end

  def running?
    active? && starts_at <= Time.current && ends_at >= Time.current
  end

  def budget_remaining_cents
    budget_cents - spent_cents
  end

  def budget_exhausted?
    budget_cents > 0 && spent_cents >= budget_cents
  end

  def ctr
    return 0.0 if impressions.zero?

    (clicks.to_f / impressions * 100).round(2)
  end

  def approve!
    update!(status: "active")
  end

  def pause!
    update!(status: "paused")
  end

  def complete!
    update!(status: "completed")
  end

  def reject!
    update!(status: "rejected")
  end

  def record_impression!
    increment!(:impressions)
  end

  def record_click!
    increment!(:clicks)
  end

  private

  def ends_at_after_starts_at
    return unless starts_at.present? && ends_at.present?

    errors.add(:ends_at, "must be after start date") if ends_at <= starts_at
  end
end
