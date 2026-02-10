# frozen_string_literal: true

# == Schema Information
#
# Table name: affiliate_clicks
#
#  id         :bigint           not null, primary key
#  clicked_at :datetime         not null
#  ip_hash    :string
#  referrer   :text
#  user_agent :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  entry_id   :bigint           not null
#
# Indexes
#
#  index_affiliate_clicks_on_clicked_at  (clicked_at)
#  index_affiliate_clicks_on_entry_id    (entry_id)
#
# Foreign Keys
#
#  fk_rails_...  (entry_id => entries.id)
#
class AffiliateClick < ApplicationRecord
  belongs_to :entry

  validates :clicked_at, presence: true

  # Scopes
  scope :recent, -> { order(clicked_at: :desc) }
  scope :today, -> { where(clicked_at: Time.current.beginning_of_day..) }
  scope :this_week, -> { where(clicked_at: 1.week.ago..) }
  scope :this_month, -> { where(clicked_at: 1.month.ago..) }
  scope :for_site, ->(site_id) { joins(:entry).where(entries: { site_id: site_id }) }

  # Class methods for analytics
  def self.count_for_entry(entry_id, since: 30.days.ago)
    where(entry_id: entry_id, clicked_at: since..).count
  end

  def self.count_by_entry(site_id:, since: 30.days.ago)
    for_site(site_id)
      .where(clicked_at: since..)
      .group(:entry_id)
      .count
  end
end
