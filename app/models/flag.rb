# frozen_string_literal: true

# == Schema Information
#
# Table name: flags
#
#  id             :bigint           not null, primary key
#  details        :text
#  flaggable_type :string           not null
#  reason         :integer          default("spam"), not null
#  reviewed_at    :datetime
#  status         :integer          default("pending"), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  flaggable_id   :bigint           not null
#  reviewed_by_id :bigint
#  site_id        :bigint           not null
#  user_id        :bigint           not null
#
# Indexes
#
#  index_flags_on_flaggable        (flaggable_type,flaggable_id)
#  index_flags_on_reviewed_by_id   (reviewed_by_id)
#  index_flags_on_site_and_status  (site_id,status)
#  index_flags_on_site_id          (site_id)
#  index_flags_on_user_id          (user_id)
#  index_flags_uniqueness          (site_id,user_id,flaggable_type,flaggable_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (reviewed_by_id => users.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (user_id => users.id)
#
class Flag < ApplicationRecord
  include SiteScoped

  # Reason enum values
  REASONS = {
    spam: 0,
    harassment: 1,
    misinformation: 2,
    inappropriate: 3,
    other: 4
  }.freeze

  # Status enum values
  STATUSES = {
    pending: 0,
    reviewed: 1,
    dismissed: 2,
    action_taken: 3
  }.freeze

  # Associations
  belongs_to :user
  belongs_to :flaggable, polymorphic: true
  belongs_to :reviewed_by, class_name: "User", optional: true

  # Enums
  enum :reason, REASONS
  enum :status, STATUSES

  # Validations
  validates :reason, presence: true
  validates :status, presence: true
  validates :details, length: { maximum: 1000 }, allow_blank: true
  validates :user_id, uniqueness: {
    scope: %i[site_id flaggable_type flaggable_id],
    message: "has already flagged this content"
  }
  validates :reviewed_at, presence: true, if: -> { reviewed_by.present? }
  validate :cannot_flag_own_content

  # Scopes
  scope :pending, -> { where(status: :pending) }
  scope :resolved, -> { where.not(status: :pending) }
  scope :for_content_items, -> { where(flaggable_type: "ContentItem") }
  scope :for_comments, -> { where(flaggable_type: "Comment") }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user) { where(user: user) }

  # Callbacks
  after_create :check_threshold_and_notify

  # Instance methods
  def resolve!(reviewer, action: :reviewed)
    update!(
      status: action,
      reviewed_by: reviewer,
      reviewed_at: Time.current
    )
  end

  def dismiss!(reviewer)
    resolve!(reviewer, action: :dismissed)
  end

  def reviewed?
    !pending?
  end

  def content_item?
    flaggable_type == "ContentItem"
  end

  def comment?
    flaggable_type == "Comment"
  end

  private

  def cannot_flag_own_content
    return unless flaggable.present? && user.present?

    if flaggable.respond_to?(:user) && flaggable.user_id == user_id
      errors.add(:base, "cannot flag your own content")
    end
  end

  def check_threshold_and_notify
    check_auto_hide_threshold
    notify_admins
  end

  def check_auto_hide_threshold
    return unless flaggable.respond_to?(:hidden?)
    return if flaggable.hidden?

    threshold = site.setting("moderation.flag_threshold", 3)
    flag_count = Flag.where(
      site: site,
      flaggable: flaggable,
      status: :pending
    ).count

    return unless flag_count >= threshold

    flaggable.update!(hidden: true) if flaggable.respond_to?(:hidden=)
  end

  def notify_admins
    return unless site.setting("moderation.flag_notifications_enabled", true)

    FlagMailer.new_flag_notification(self).deliver_later
  end
end
