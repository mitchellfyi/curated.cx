# frozen_string_literal: true

class SiteBan < ApplicationRecord
  include SiteScoped

  # Associations
  belongs_to :user
  belongs_to :banned_by, class_name: "User"

  # Validations
  validates :banned_at, presence: true
  validates :user_id, uniqueness: { scope: :site_id, message: "is already banned from this site" }
  validate :cannot_ban_self, on: :create

  # Scopes
  scope :active, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at IS NOT NULL AND expires_at <= ?", Time.current) }
  scope :permanent, -> { where(expires_at: nil) }
  scope :for_user, ->(user) { where(user: user) }

  # Callbacks
  before_validation :set_banned_at, on: :create

  # Instance methods
  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def active?
    !expired?
  end

  def permanent?
    expires_at.nil?
  end

  private

  def set_banned_at
    self.banned_at ||= Time.current
  end

  def cannot_ban_self
    return unless user_id == banned_by_id

    errors.add(:user, "cannot ban yourself")
  end
end
