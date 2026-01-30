# frozen_string_literal: true

class Discussion < ApplicationRecord
  include SiteScoped

  # Maximum body length
  BODY_MAX_LENGTH = 10_000
  TITLE_MAX_LENGTH = 200

  # Enums - using prefix to avoid conflict with ActiveRecord's public method
  enum :visibility, { public_access: 0, subscribers_only: 1 }, prefix: :visibility

  # Associations
  belongs_to :user
  belongs_to :locked_by, class_name: "User", optional: true
  has_many :posts, class_name: "DiscussionPost", dependent: :destroy

  # Validations
  validates :title, presence: true, length: { maximum: TITLE_MAX_LENGTH }
  validates :body, length: { maximum: BODY_MAX_LENGTH }, allow_blank: true
  validates :visibility, presence: true

  # Scopes
  scope :pinned_first, -> { order(pinned: :desc, last_post_at: :desc) }
  scope :recent_activity, -> { order(last_post_at: :desc) }
  scope :publicly_visible, -> { where(visibility: :public_access) }
  scope :unlocked, -> { where(locked_at: nil) }

  # Instance methods
  def locked?
    locked_at.present?
  end

  def lock!(user)
    update!(locked_at: Time.current, locked_by: user)
  end

  def unlock!
    update!(locked_at: nil, locked_by: nil)
  end

  def pin!
    update!(pinned: true, pinned_at: Time.current)
  end

  def unpin!
    update!(pinned: false, pinned_at: nil)
  end

  def touch_last_post!
    update_column(:last_post_at, Time.current)
  end
end
