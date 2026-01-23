# frozen_string_literal: true

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
  before_validation :set_tenant_from_site, on: :create

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

  def set_tenant_from_site
    self.tenant = site.tenant if site.present? && tenant.nil?
  end
end
