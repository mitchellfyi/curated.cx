# frozen_string_literal: true

# == Schema Information
#
# Table name: votes
#
#  id           :bigint           not null, primary key
#  value        :integer          default(1), not null
#  votable_type :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  site_id      :bigint           not null
#  user_id      :bigint           not null
#  votable_id   :bigint           not null
#
# Indexes
#
#  index_votes_on_site_id  (site_id)
#  index_votes_on_user_id  (user_id)
#  index_votes_on_votable  (votable_type,votable_id)
#  index_votes_uniqueness  (site_id,user_id,votable_type,votable_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (user_id => users.id)
#
class Vote < ApplicationRecord
  include SiteScoped

  # Associations
  belongs_to :user
  belongs_to :votable, polymorphic: true, counter_cache: :upvotes_count

  # Validations
  validates :value, presence: true, numericality: { only_integer: true }
  validates :user_id, uniqueness: { scope: %i[site_id votable_type votable_id], message: "has already voted on this content" }

  # Scopes
  scope :for_content_item, ->(item) { where(votable: item) }
  scope :for_note, ->(note) { where(votable: note) }
  scope :by_user, ->(user) { where(user: user) }
  scope :content_items, -> { where(votable_type: "ContentItem") }
  scope :notes, -> { where(votable_type: "Note") }
end
