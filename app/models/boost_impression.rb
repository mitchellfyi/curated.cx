# frozen_string_literal: true

# == Schema Information
#
# Table name: boost_impressions
#
#  id               :bigint           not null, primary key
#  ip_hash          :string
#  shown_at         :datetime         not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  network_boost_id :bigint           not null
#  site_id          :bigint           not null
#
# Indexes
#
#  index_boost_impressions_on_network_boost_id               (network_boost_id)
#  index_boost_impressions_on_network_boost_id_and_shown_at  (network_boost_id,shown_at)
#  index_boost_impressions_on_site_id                        (site_id)
#  index_boost_impressions_on_site_id_and_shown_at           (site_id,shown_at)
#
# Foreign Keys
#
#  fk_rails_...  (network_boost_id => network_boosts.id)
#  fk_rails_...  (site_id => sites.id)
#
class BoostImpression < ApplicationRecord
  # Associations
  belongs_to :network_boost
  belongs_to :site

  # Validations
  validates :shown_at, presence: true

  # Scopes
  scope :recent, -> { order(shown_at: :desc) }
  scope :today, -> { where(shown_at: Time.current.beginning_of_day..) }
  scope :this_week, -> { where(shown_at: 1.week.ago..) }
  scope :this_month, -> { where(shown_at: 1.month.ago..) }
  scope :for_site, ->(site) { where(site: site) }
  scope :for_boost, ->(boost) { where(network_boost: boost) }

  # Class methods for analytics
  def self.count_for_boost(boost_id, since: 30.days.ago)
    where(network_boost_id: boost_id, shown_at: since..).count
  end

  def self.count_by_date(since: 30.days.ago)
    where(shown_at: since..)
      .group("DATE(shown_at)")
      .count
  end
end
