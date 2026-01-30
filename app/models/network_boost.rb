# frozen_string_literal: true

# == Schema Information
#
# Table name: network_boosts
#
#  id               :bigint           not null, primary key
#  cpc_rate         :decimal(8, 2)    not null
#  enabled          :boolean          default(TRUE), not null
#  monthly_budget   :decimal(10, 2)
#  spent_this_month :decimal(10, 2)   default(0.0)
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  source_site_id   :bigint           not null
#  target_site_id   :bigint           not null
#
# Indexes
#
#  index_network_boosts_on_source_site_id                     (source_site_id)
#  index_network_boosts_on_source_site_id_and_target_site_id  (source_site_id,target_site_id) UNIQUE
#  index_network_boosts_on_target_site_id                     (target_site_id)
#  index_network_boosts_on_target_site_id_and_enabled         (target_site_id,enabled)
#
# Foreign Keys
#
#  fk_rails_...  (source_site_id => sites.id)
#  fk_rails_...  (target_site_id => sites.id)
#
class NetworkBoost < ApplicationRecord
  # Associations
  belongs_to :source_site, class_name: "Site"
  belongs_to :target_site, class_name: "Site"
  has_many :boost_impressions, dependent: :destroy
  has_many :boost_clicks, dependent: :destroy

  # Validations
  validates :cpc_rate, presence: true, numericality: { greater_than: 0 }
  validates :monthly_budget, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :source_site_id, uniqueness: { scope: :target_site_id, message: "already has a boost to this target site" }
  validate :source_and_target_different

  # Scopes
  scope :enabled, -> { where(enabled: true) }
  scope :with_budget, -> { where("monthly_budget IS NULL OR spent_this_month < monthly_budget") }
  scope :for_source_site, ->(site) { where(source_site: site) }
  scope :for_target_site, ->(site) { where(target_site: site) }

  # Check if this boost has remaining budget
  def has_budget?
    monthly_budget.nil? || spent_this_month < monthly_budget
  end

  # Calculate remaining budget
  def remaining_budget
    return nil if monthly_budget.nil?

    monthly_budget - spent_this_month
  end

  # Record a click and update spent amount
  def record_click!
    increment!(:spent_this_month, cpc_rate)
  end

  # Reset monthly spending (called by monthly job)
  def reset_monthly_spending!
    update!(spent_this_month: 0)
  end

  private

  def source_and_target_different
    if source_site_id.present? && source_site_id == target_site_id
      errors.add(:target_site, "must be different from source site")
    end
  end
end
