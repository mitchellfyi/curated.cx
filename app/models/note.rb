# frozen_string_literal: true

# == Schema Information
#
# Table name: notes
#
#  id             :bigint           not null, primary key
#  body           :text             not null
#  comments_count :integer          default(0), not null
#  hidden_at      :datetime
#  link_preview   :jsonb
#  published_at   :datetime
#  reposts_count  :integer          default(0), not null
#  upvotes_count  :integer          default(0), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  hidden_by_id   :bigint
#  repost_of_id   :bigint
#  site_id        :bigint           not null
#  user_id        :bigint           not null
#
# Indexes
#
#  index_notes_on_hidden_at                 (hidden_at)
#  index_notes_on_hidden_by_id              (hidden_by_id)
#  index_notes_on_repost_of_id              (repost_of_id)
#  index_notes_on_site_id                   (site_id)
#  index_notes_on_site_id_and_published_at  (site_id,published_at DESC)
#  index_notes_on_user_id                   (user_id)
#  index_notes_on_user_id_and_created_at    (user_id,created_at DESC)
#
# Foreign Keys
#
#  fk_rails_...  (hidden_by_id => users.id)
#  fk_rails_...  (repost_of_id => notes.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (user_id => users.id)
#
class Note < ApplicationRecord
  include SiteScoped

  # Constants
  BODY_MAX_LENGTH = 500

  # Associations
  belongs_to :user

  # Delegate common user attributes for cleaner views
  delegate :avatar_url, :profile_name, :initials, to: :user, prefix: :author, allow_nil: true

  # Delegate common site attributes
  delegate :name, :primary_domain, :primary_hostname, to: :site, prefix: true, allow_nil: true
  belongs_to :hidden_by, class_name: "User", optional: true
  belongs_to :repost_of, class_name: "Note", optional: true, counter_cache: :reposts_count
  has_many :reposts, class_name: "Note", foreign_key: :repost_of_id, dependent: :nullify, inverse_of: :repost_of
  has_many :votes, as: :votable, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy
  has_many :flags, as: :flaggable, dependent: :destroy

  # Active Storage
  has_one_attached :image

  # Validations
  validates :body, presence: true, length: { maximum: BODY_MAX_LENGTH }
  validates :upvotes_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :comments_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :reposts_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :repost_cannot_be_of_repost

  # Callbacks
  after_create :enqueue_link_preview_extraction

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :published, -> { where.not(published_at: nil) }
  scope :drafts, -> { where(published_at: nil) }
  scope :not_hidden, -> { where(hidden_at: nil) }
  scope :for_feed, -> { published.not_hidden.order(published_at: :desc) }
  scope :by_user, ->(user) { where(user: user) }
  scope :original, -> { where(repost_of_id: nil) }
  scope :reposts_only, -> { where.not(repost_of_id: nil) }
  scope :published_since, ->(time) { published.where("published_at >= ?", time) }
  scope :top_this_week, -> { published_since(1.week.ago).order(Arel.sql("(upvotes_count + comments_count) DESC, published_at DESC")) }
  scope :by_engagement, -> { order(Arel.sql("(upvotes_count + comments_count) DESC")) }

  # Instance methods
  def published?
    published_at.present?
  end

  def draft?
    published_at.nil?
  end

  def hidden?
    hidden_at.present?
  end

  def repost?
    repost_of_id.present?
  end

  def original_note
    repost_of || self
  end

  def link_preview
    super || {}
  end

  def has_link_preview?
    link_preview.present? && link_preview["url"].present?
  end

  def publish!
    update!(published_at: Time.current) unless published?
  end

  def unpublish!
    update!(published_at: nil) if published?
  end

  def hide!(user)
    update!(hidden_at: Time.current, hidden_by: user)
  end

  def unhide!
    update!(hidden_at: nil, hidden_by: nil)
  end

  # Extract first URL from body text
  def extract_first_url
    return nil if body.blank?

    url_regex = %r{https?://[^\s<>\[\]"'()]+}i
    body.match(url_regex)&.to_s
  end

  private

  def repost_cannot_be_of_repost
    return unless repost_of.present?

    if repost_of.repost?
      errors.add(:repost_of, "cannot be a repost of another repost")
    end
  end

  def enqueue_link_preview_extraction
    url = extract_first_url
    return unless url.present?

    ExtractNoteLinkPreviewJob.perform_later(id, url)
  end
end
