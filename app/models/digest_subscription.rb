# frozen_string_literal: true

# == Schema Information
#
# Table name: digest_subscriptions
#
#  id                :bigint           not null, primary key
#  active            :boolean          default(TRUE), not null
#  frequency         :integer          default("weekly"), not null
#  last_sent_at      :datetime
#  preferences       :jsonb            not null
#  unsubscribe_token :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  site_id           :bigint           not null
#  user_id           :bigint           not null
#
# Indexes
#
#  index_digest_subscriptions_on_site_id                           (site_id)
#  index_digest_subscriptions_on_site_id_and_frequency_and_active  (site_id,frequency,active)
#  index_digest_subscriptions_on_unsubscribe_token                 (unsubscribe_token) UNIQUE
#  index_digest_subscriptions_on_user_id                           (user_id)
#  index_digest_subscriptions_on_user_id_and_site_id               (user_id,site_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (user_id => users.id)
#
class DigestSubscription < ApplicationRecord
  include SiteScoped

  # Enums
  enum :frequency, { weekly: 0, daily: 1 }, default: :weekly

  # Associations
  belongs_to :user
  belongs_to :site

  # Validations
  validates :user_id, uniqueness: { scope: :site_id, message: "already subscribed to this site" }
  validates :unsubscribe_token, presence: true, uniqueness: true
  validates :frequency, presence: true

  # Callbacks
  before_validation :generate_unsubscribe_token, on: :create

  # Scopes
  scope :active, -> { where(active: true) }
  scope :due_for_weekly, -> {
    active.weekly.where("last_sent_at IS NULL OR last_sent_at < ?", 1.week.ago)
  }
  scope :due_for_daily, -> {
    active.daily.where("last_sent_at IS NULL OR last_sent_at < ?", 1.day.ago)
  }

  def preferences
    super || {}
  end

  def mark_sent!
    update!(last_sent_at: Time.current)
  end

  def unsubscribe!
    update!(active: false)
  end

  def resubscribe!
    update!(active: true)
  end

  private

  def generate_unsubscribe_token
    self.unsubscribe_token ||= SecureRandom.urlsafe_base64(32)
  end
end
