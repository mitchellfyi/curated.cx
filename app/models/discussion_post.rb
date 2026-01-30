# frozen_string_literal: true

# == Schema Information
#
# Table name: discussion_posts
#
#  id            :bigint           not null, primary key
#  body          :text             not null
#  edited_at     :datetime
#  hidden_at     :datetime
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  discussion_id :bigint           not null
#  parent_id     :bigint
#  site_id       :bigint           not null
#  user_id       :bigint           not null
#
# Indexes
#
#  index_discussion_posts_on_discussion_id                 (discussion_id)
#  index_discussion_posts_on_discussion_id_and_created_at  (discussion_id,created_at)
#  index_discussion_posts_on_parent_id                     (parent_id)
#  index_discussion_posts_on_site_id                       (site_id)
#  index_discussion_posts_on_site_id_and_user_id           (site_id,user_id)
#  index_discussion_posts_on_user_id                       (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (discussion_id => discussions.id)
#  fk_rails_...  (parent_id => discussion_posts.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (user_id => users.id)
#
class DiscussionPost < ApplicationRecord
  include SiteScoped

  # Maximum body length
  BODY_MAX_LENGTH = 10_000

  # Associations
  belongs_to :user
  belongs_to :discussion, counter_cache: :posts_count
  belongs_to :parent, class_name: "DiscussionPost", optional: true
  has_many :replies, class_name: "DiscussionPost", foreign_key: :parent_id, dependent: :destroy, inverse_of: :parent
  has_many :flags, as: :flaggable, dependent: :destroy

  # Validations
  validates :body, presence: true, length: { maximum: BODY_MAX_LENGTH }
  validate :parent_belongs_to_same_discussion, if: :parent_id?

  # Scopes
  scope :root_posts, -> { where(parent_id: nil) }
  scope :oldest_first, -> { order(created_at: :asc) }
  scope :recent, -> { order(created_at: :desc) }
  scope :visible, -> { where(hidden_at: nil) }

  # Callbacks
  after_create :touch_discussion_last_post

  # Instance methods
  def root?
    parent_id.nil?
  end

  def reply?
    parent_id.present?
  end

  def edited?
    edited_at.present?
  end

  def hidden?
    hidden_at.present?
  end

  def mark_as_edited!
    update_column(:edited_at, Time.current)
  end

  private

  def parent_belongs_to_same_discussion
    return unless parent.present?

    if parent.discussion_id != discussion_id
      errors.add(:parent, "must belong to the same discussion")
    end
  end

  def touch_discussion_last_post
    discussion.touch_last_post!
  end
end
