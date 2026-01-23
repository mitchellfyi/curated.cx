# frozen_string_literal: true

class Vote < ApplicationRecord
  include SiteScoped

  # Associations
  belongs_to :user
  belongs_to :content_item, counter_cache: :upvotes_count

  # Validations
  validates :value, presence: true, numericality: { only_integer: true }
  validates :user_id, uniqueness: { scope: %i[site_id content_item_id], message: "has already voted on this content" }

  # Scopes
  scope :for_content_item, ->(content_item) { where(content_item: content_item) }
  scope :by_user, ->(user) { where(user: user) }
end
