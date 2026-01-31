# frozen_string_literal: true

# == Schema Information
#
# Table name: subscriber_tags
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  slug       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  site_id    :bigint           not null
#  tenant_id  :bigint           not null
#
# Indexes
#
#  index_subscriber_tags_on_site_id           (site_id)
#  index_subscriber_tags_on_site_id_and_slug  (site_id,slug) UNIQUE
#  index_subscriber_tags_on_tenant_id         (tenant_id)
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
class SubscriberTag < ApplicationRecord
  include SiteScoped

  # Associations
  belongs_to :tenant
  has_many :subscriber_taggings, dependent: :destroy
  has_many :digest_subscriptions, through: :subscriber_taggings

  # Validations
  validates :name, presence: true, length: { maximum: 100 }
  validates :slug, presence: true,
                   format: { with: /\A[a-z0-9_-]+\z/, message: "must contain only lowercase letters, numbers, hyphens, and underscores" },
                   uniqueness: { scope: :site_id }

  # Callbacks
  before_validation :generate_slug, on: :create

  # Scopes
  scope :alphabetical, -> { order(:name) }

  def to_param
    slug
  end

  private

  def generate_slug
    return if slug.present?
    return unless name.present?

    base_slug = name.parameterize
    self.slug = base_slug
  end
end
