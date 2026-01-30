# frozen_string_literal: true

# == Schema Information
#
# Table name: referral_reward_tiers
#
#  id                 :bigint           not null, primary key
#  active             :boolean          default(TRUE), not null
#  description        :text
#  milestone          :integer          not null
#  name               :string           not null
#  reward_data        :jsonb            not null
#  reward_type        :integer          default("digital_download"), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  digital_product_id :bigint
#  site_id            :bigint           not null
#
# Indexes
#
#  index_referral_reward_tiers_on_digital_product_id     (digital_product_id)
#  index_referral_reward_tiers_on_site_id                (site_id)
#  index_referral_reward_tiers_on_site_id_and_active     (site_id,active)
#  index_referral_reward_tiers_on_site_id_and_milestone  (site_id,milestone) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (digital_product_id => digital_products.id)
#  fk_rails_...  (site_id => sites.id)
#
class ReferralRewardTier < ApplicationRecord
  include SiteScoped

  # Associations
  belongs_to :digital_product, optional: true

  # Enums
  enum :reward_type, { digital_download: 0, featured_mention: 1, custom: 2 }, default: :digital_download

  # Validations
  validates :milestone, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :milestone, uniqueness: { scope: :site_id, message: "already has a reward tier" }
  validates :name, presence: true
  validates :reward_type, presence: true

  # Scopes
  scope :active, -> { where(active: true) }
  scope :ordered_by_milestone, -> { order(milestone: :asc) }

  # Default reward_data if nil
  def reward_data
    super || {}
  end

  # Get the download URL for digital_download rewards
  # Returns the digital product's download path if linked, otherwise falls back to reward_data URL
  def download_url
    if digital_product.present?
      nil # Download handled via Purchase/DownloadToken
    else
      reward_data["download_url"]
    end
  end

  # Check if this tier grants a digital product
  def grants_digital_product?
    digital_download? && digital_product.present?
  end

  # Get the featured mention details for featured_mention rewards
  def mention_details
    reward_data["mention_details"]
  end

  # Get custom reward instructions
  def instructions
    reward_data["instructions"]
  end
end
