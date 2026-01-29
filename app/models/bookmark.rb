# frozen_string_literal: true

# == Schema Information
#
# Table name: bookmarks
#
#  id                :bigint           not null, primary key
#  bookmarkable_type :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  bookmarkable_id   :bigint           not null
#  user_id           :bigint           not null
#
# Indexes
#
#  index_bookmarks_on_bookmarkable  (bookmarkable_type,bookmarkable_id)
#  index_bookmarks_on_user_id       (user_id)
#  index_bookmarks_uniqueness       (user_id,bookmarkable_type,bookmarkable_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Bookmark < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :bookmarkable, polymorphic: true

  # Validations
  validates :user_id, uniqueness: { scope: [ :bookmarkable_type, :bookmarkable_id ], message: "already bookmarked this item" }

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :content_items, -> { where(bookmarkable_type: "ContentItem") }
  scope :listings, -> { where(bookmarkable_type: "Listing") }

  # Class methods
  def self.bookmarked?(user, bookmarkable)
    return false unless user

    exists?(user: user, bookmarkable: bookmarkable)
  end
end
