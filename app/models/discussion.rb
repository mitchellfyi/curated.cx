# frozen_string_literal: true

# == Schema Information
#
# Table name: discussions
#
#  id           :bigint           not null, primary key
#  body         :text
#  last_post_at :datetime
#  locked_at    :datetime
#  pinned       :boolean          default(FALSE), not null
#  pinned_at    :datetime
#  posts_count  :integer          default(0), not null
#  title        :string           not null
#  visibility   :integer          default("public_access"), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  locked_by_id :bigint
#  site_id      :bigint           not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_discussions_on_locked_by_id                         (locked_by_id)
#  index_discussions_on_site_id                              (site_id)
#  index_discussions_on_site_id_and_last_post_at             (site_id,last_post_at)
#  index_discussions_on_site_id_and_pinned_and_last_post_at  (site_id,pinned,last_post_at)
#  index_discussions_on_site_id_and_visibility               (site_id,visibility)
#  index_discussions_on_user_id                              (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (locked_by_id => users.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (user_id => users.id)
#
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
