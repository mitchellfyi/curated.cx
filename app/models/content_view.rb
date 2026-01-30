# frozen_string_literal: true

# == Schema Information
#
# Table name: content_views
#
#  id              :bigint           not null, primary key
#  viewed_at       :datetime         not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  content_item_id :bigint           not null
#  site_id         :bigint           not null
#  user_id         :bigint           not null
#
# Indexes
#
#  index_content_views_on_content_item_id       (content_item_id)
#  index_content_views_on_site_id               (site_id)
#  index_content_views_on_user_id               (user_id)
#  index_content_views_on_user_site_viewed_at   (user_id,site_id,viewed_at DESC)
#  index_content_views_uniqueness               (site_id,user_id,content_item_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (content_item_id => content_items.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (user_id => users.id)
#
class ContentView < ApplicationRecord
  include SiteScoped

  # Associations
  belongs_to :user
  belongs_to :content_item

  # Validations
  validates :user_id, uniqueness: { scope: [ :site_id, :content_item_id ], message: "has already viewed this content" }

  # Scopes
  scope :recent, -> { order(viewed_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }
  scope :since, ->(time) { where("viewed_at >= ?", time) }
end
