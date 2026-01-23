# frozen_string_literal: true

# == Schema Information
#
# Table name: taxonomies
#
#  id          :bigint           not null, primary key
#  description :text
#  name        :string           not null
#  position    :integer          default(0), not null
#  slug        :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  parent_id   :bigint
#  site_id     :bigint           not null
#  tenant_id   :bigint           not null
#
# Indexes
#
#  index_taxonomies_on_site_id                (site_id)
#  index_taxonomies_on_site_id_and_parent_id  (site_id,parent_id)
#  index_taxonomies_on_site_id_and_slug       (site_id,slug) UNIQUE
#  index_taxonomies_on_tenant_id              (tenant_id)
#
# Foreign Keys
#
#  fk_rails_...  (parent_id => taxonomies.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
class Taxonomy < ApplicationRecord
  include TenantScoped
  include SiteScoped

  # Associations
  belongs_to :tenant
  belongs_to :parent, class_name: "Taxonomy", optional: true
  has_many :children, class_name: "Taxonomy", foreign_key: :parent_id, dependent: :destroy, inverse_of: :parent
  has_many :tagging_rules, dependent: :destroy

  # Validations
  validates :name, presence: true
  validates :slug, presence: true,
                   uniqueness: { scope: :site_id },
                   format: { with: /\A[a-z0-9-]+\z/, message: "only allows lowercase letters, numbers, and hyphens" }

  # Callbacks
  before_validation :generate_slug_from_name, if: -> { slug.blank? && name.present? }

  # Scopes
  scope :roots, -> { where(parent_id: nil) }
  scope :by_position, -> { order(position: :asc) }

  # Instance methods
  def ancestors
    result = []
    current = parent
    while current
      result.unshift(current)
      current = current.parent
    end
    result
  end

  def descendants
    result = []
    children.each do |child|
      result << child
      result.concat(child.descendants)
    end
    result
  end

  def full_path
    (ancestors.map(&:name) + [ name ]).join(" / ")
  end

  def root?
    parent_id.nil?
  end

  private

  def generate_slug_from_name
    self.slug = name.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-|-$/, "")
  end
end
