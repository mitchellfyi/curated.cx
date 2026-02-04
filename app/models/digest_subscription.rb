# frozen_string_literal: true

# == Schema Information
#
# Table name: digest_subscriptions
#
#  id                    :bigint           not null, primary key
#  active                :boolean          default(TRUE), not null
#  confirmation_sent_at  :datetime
#  confirmation_token    :string
#  confirmed_at          :datetime
#  frequency             :integer          default("weekly"), not null
#  last_sent_at          :datetime
#  preferences           :jsonb            not null
#  referral_code         :string           not null
#  unsubscribe_token     :string           not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  site_id               :bigint           not null
#  user_id               :bigint           not null
#
# Indexes
#
#  index_digest_subscriptions_on_confirmation_token               (confirmation_token) UNIQUE
#  index_digest_subscriptions_on_referral_code                     (referral_code) UNIQUE
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

  # Associations for referrals
  has_many :referrals_as_referrer, class_name: "Referral", foreign_key: :referrer_subscription_id, dependent: :nullify, inverse_of: :referrer_subscription
  has_one :referral_as_referee, class_name: "Referral", foreign_key: :referee_subscription_id, dependent: :nullify, inverse_of: :referee_subscription

  # Associations for email sequences
  has_many :sequence_enrollments, dependent: :destroy

  # Associations for subscriber tagging
  has_many :subscriber_taggings, dependent: :destroy
  has_many :subscriber_tags, through: :subscriber_taggings

  # Validations
  validates :user_id, uniqueness: { scope: :site_id, message: "already subscribed to this site" }
  validates :unsubscribe_token, presence: true, uniqueness: true
  validates :referral_code, presence: true, uniqueness: true
  validates :confirmation_token, uniqueness: true, allow_nil: true
  validates :frequency, presence: true

  # Callbacks
  before_validation :generate_unsubscribe_token, on: :create
  before_validation :generate_referral_code, on: :create
  before_validation :generate_confirmation_token, on: :create
  after_create_commit :enroll_in_sequences
  after_create_commit :send_confirmation_email

  # Scopes
  scope :active, -> { where(active: true) }
  scope :confirmed, -> { where.not(confirmed_at: nil) }
  scope :pending_confirmation, -> { where(confirmed_at: nil) }
  scope :due_for_weekly, -> {
    active.confirmed.weekly.where("last_sent_at IS NULL OR last_sent_at < ?", 1.week.ago)
  }
  scope :due_for_daily, -> {
    active.confirmed.daily.where("last_sent_at IS NULL OR last_sent_at < ?", 1.day.ago)
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

  # Generate referral link URL for sharing
  def referral_link
    host = site.primary_hostname || "curated.cx"
    "https://#{host}/subscribe?ref=#{referral_code}"
  end

  # Count of confirmed referrals for this subscription
  def confirmed_referrals_count
    referrals_as_referrer.confirmed.count + referrals_as_referrer.rewarded.count
  end

  # Confirmation methods (double opt-in)
  def confirmed?
    confirmed_at.present?
  end

  def pending_confirmation?
    confirmed_at.nil?
  end

  def confirm!
    return true if confirmed?

    update!(confirmed_at: Time.current, confirmation_token: nil)
  end

  def resend_confirmation!
    return false if confirmed?

    generate_confirmation_token
    update!(confirmation_sent_at: Time.current)
    DigestMailer.confirmation(self).deliver_later
    true
  end

  # Generate confirmation link URL
  def confirmation_link
    return nil if confirmed? || confirmation_token.blank?

    host = site.primary_hostname || "curated.cx"
    "https://#{host}/digest_subscription/confirm/#{confirmation_token}"
  end

  private

  def generate_unsubscribe_token
    self.unsubscribe_token ||= SecureRandom.urlsafe_base64(32)
  end

  def generate_referral_code
    self.referral_code ||= SecureRandom.urlsafe_base64(8)
  end

  def generate_confirmation_token
    self.confirmation_token ||= SecureRandom.urlsafe_base64(32)
  end

  def enroll_in_sequences
    SequenceEnrollmentService.new(self).enroll_on_subscription!
  end

  def send_confirmation_email
    return if confirmed? # Skip for already confirmed (e.g., migrated records)

    update_column(:confirmation_sent_at, Time.current)
    DigestMailer.confirmation(self).deliver_later
  end
end
