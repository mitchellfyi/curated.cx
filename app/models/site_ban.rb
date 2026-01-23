# frozen_string_literal: true

# == Schema Information
#
# Table name: site_bans
#
#  id           :bigint           not null, primary key
#  banned_at    :datetime         not null
#  expires_at   :datetime
#  reason       :text
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  banned_by_id :bigint           not null
#  site_id      :bigint           not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_site_bans_on_banned_by_id      (banned_by_id)
#  index_site_bans_on_site_and_expires  (site_id,expires_at)
#  index_site_bans_on_site_id           (site_id)
#  index_site_bans_on_user_id           (user_id)
#  index_site_bans_uniqueness           (site_id,user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (banned_by_id => users.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (user_id => users.id)
#
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
