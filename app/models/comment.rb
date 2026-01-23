# frozen_string_literal: true

class Comment < ApplicationRecord
  include SiteScoped

  # Maximum body length
  BODY_MAX_LENGTH = 10_000

  # Associations
  belongs_to :user
  belongs_to :content_item, counter_cache: :comments_count
  belongs_to :parent, class_name: "Comment", optional: true
  has_many :replies, class_name: "Comment", foreign_key: :parent_id, dependent: :destroy, inverse_of: :parent

  # Validations
  validates :body, presence: true, length: { maximum: BODY_MAX_LENGTH }
  validate :parent_belongs_to_same_content_item, if: :parent_id?

  # Scopes
  scope :root_comments, -> { where(parent_id: nil) }
  scope :replies_to, ->(comment) { where(parent: comment) }
  scope :recent, -> { order(created_at: :desc) }
  scope :oldest_first, -> { order(created_at: :asc) }
  scope :for_content_item, ->(content_item) { where(content_item: content_item) }

  # Instance methods
  def edited?
    edited_at.present?
  end

  def root?
    parent_id.nil?
  end

  def reply?
    parent_id.present?
  end

  def mark_as_edited!
    update_column(:edited_at, Time.current)
  end

  private

  def parent_belongs_to_same_content_item
    return unless parent.present?

    if parent.content_item_id != content_item_id
      errors.add(:parent, "must belong to the same content item")
    end
  end
end
