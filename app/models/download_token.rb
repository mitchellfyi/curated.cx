# frozen_string_literal: true

# == Schema Information
#
# Table name: download_tokens
#
#  id                 :bigint           not null, primary key
#  download_count     :integer          default(0), not null
#  expires_at         :datetime         not null
#  last_downloaded_at :datetime
#  max_downloads      :integer          default(5), not null
#  token              :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  purchase_id        :bigint           not null
#
# Indexes
#
#  index_download_tokens_on_expires_at   (expires_at)
#  index_download_tokens_on_purchase_id  (purchase_id)
#  index_download_tokens_on_token        (token) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (purchase_id => purchases.id)
#
class DownloadToken < ApplicationRecord
  TOKEN_LENGTH = 32
  DEFAULT_EXPIRY_HOURS = 1
  DEFAULT_MAX_DOWNLOADS = 5

  # Associations
  belongs_to :purchase
  has_one :digital_product, through: :purchase

  # Validations
  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validates :download_count, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :max_downloads, presence: true, numericality: { only_integer: true, greater_than: 0 }

  # Callbacks
  before_validation :generate_token!, on: :create, if: -> { token.blank? }
  before_validation :set_default_expiry, on: :create, if: -> { expires_at.blank? }

  # Scopes
  scope :active, -> { where("expires_at > ?", Time.current).where("download_count < max_downloads") }
  scope :expired, -> { where("expires_at <= ?", Time.current) }
  scope :exhausted, -> { where("download_count >= max_downloads") }

  # Instance methods
  def expired?
    expires_at <= Time.current
  end

  def exhausted?
    download_count >= max_downloads
  end

  def valid_for_download?
    !expired? && !exhausted?
  end

  def downloads_remaining
    [ max_downloads - download_count, 0 ].max
  end

  def record_download!
    return false unless valid_for_download?

    update!(
      download_count: download_count + 1,
      last_downloaded_at: Time.current
    )
    true
  end

  def regenerate!
    generate_token!
    self.expires_at = DEFAULT_EXPIRY_HOURS.hours.from_now
    self.download_count = 0
    save!
  end

  private

  def generate_token!
    loop do
      self.token = SecureRandom.urlsafe_base64(TOKEN_LENGTH)
      break unless self.class.exists?(token: token)
    end
  end

  def set_default_expiry
    self.expires_at = DEFAULT_EXPIRY_HOURS.hours.from_now
  end
end
