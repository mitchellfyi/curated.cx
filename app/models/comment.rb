# frozen_string_literal: true

# == Schema Information
#
# Table name: comments
#
#  id               :bigint           not null, primary key
#  body             :text             not null
#  commentable_type :string           not null
#  edited_at        :datetime
#  hidden_at        :datetime
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  commentable_id   :bigint           not null
#  hidden_by_id     :bigint
#  parent_id        :bigint
#  site_id          :bigint           not null
#  user_id          :bigint           not null
#
# Indexes
#
#  index_comments_on_commentable             (commentable_type,commentable_id)
#  index_comments_on_commentable_and_parent  (commentable_type,commentable_id,parent_id)
#  index_comments_on_hidden_at               (hidden_at)
#  index_comments_on_parent_id               (parent_id)
#  index_comments_on_site_and_user           (site_id,user_id)
#  index_comments_on_site_id                 (site_id)
#  index_comments_on_user_id                 (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (hidden_by_id => users.id)
#  fk_rails_...  (parent_id => comments.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (user_id => users.id)
#
class Comment < ApplicationRecord
  include SiteScoped

  # Maximum body length
  BODY_MAX_LENGTH = 10_000

  # Associations
  belongs_to :user
  belongs_to :commentable, polymorphic: true, counter_cache: :comments_count
  belongs_to :parent, class_name: "Comment", optional: true
  belongs_to :hidden_by, class_name: "User", optional: true
  has_many :replies, class_name: "Comment", foreign_key: :parent_id, dependent: :destroy, inverse_of: :parent
  has_many :flags, as: :flaggable, dependent: :destroy

  # Validations
  validates :body, presence: true, length: { maximum: BODY_MAX_LENGTH }
  validate :parent_belongs_to_same_commentable, if: :parent_id?

  # Scopes
  scope :root_comments, -> { where(parent_id: nil) }
  scope :replies_to, ->(comment) { where(parent: comment) }
  scope :recent, -> { order(created_at: :desc) }
  scope :oldest_first, -> { order(created_at: :asc) }
  scope :for_entry, ->(item) { where(commentable: item) }
  scope :for_note, ->(note) { where(commentable: note) }
  scope :for_entries, -> { where(commentable_type: "Entry") }
  scope :notes, -> { where(commentable_type: "Note") }
  scope :visible, -> { where(hidden_at: nil) }
  scope :hidden, -> { where.not(hidden_at: nil) }

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

  def hidden?
    hidden_at.present?
  end

  def visible?
    !hidden?
  end

  def hide!(user)
    update!(hidden_at: Time.current, hidden_by: user)
  end

  def unhide!
    update!(hidden_at: nil, hidden_by: nil)
  end

  def mark_as_edited!
    update_column(:edited_at, Time.current)
  end

  # Convenience method for Entry comments
  def entry
    return nil unless commentable_type == "Entry"
    commentable
  end

  # Check if comments are locked on the commentable (Entry)
  def comments_locked?
    commentable.respond_to?(:comments_locked?) && commentable.comments_locked?
  end

  private

  def parent_belongs_to_same_commentable
    return unless parent.present?

    if parent.commentable_type != commentable_type || parent.commentable_id != commentable_id
      errors.add(:parent, "must belong to the same #{commentable_type.underscore.humanize.downcase}")
    end
  end
end
