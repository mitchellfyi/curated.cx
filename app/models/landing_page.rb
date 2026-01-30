# frozen_string_literal: true

# == Schema Information
#
# Table name: landing_pages
#
#  id             :bigint           not null, primary key
#  content        :jsonb            not null
#  cta_text       :string
#  cta_url        :string
#  headline       :string
#  hero_image_url :string
#  published      :boolean          default(FALSE), not null
#  slug           :string           not null
#  subheadline    :text
#  title          :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  site_id        :bigint           not null
#  tenant_id      :bigint           not null
#
# Indexes
#
#  index_landing_pages_on_site_id                (site_id)
#  index_landing_pages_on_site_id_and_published  (site_id,published)
#  index_landing_pages_on_site_id_and_slug       (site_id,slug) UNIQUE
#  index_landing_pages_on_tenant_id              (tenant_id)
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (tenant_id => tenants.id)
#

# Landing pages for marketing campaigns, launches, and partnerships.
#
# Content is stored as JSONB with the following structure:
# {
#   sections: [
#     { type: "features", title: "...", items: [...] },
#     { type: "testimonials", items: [...] },
#     { type: "faq", items: [...] },
#     { type: "listings", listing_ids: [...] },
#     { type: "html", content: "..." }
#   ],
#   custom_css: "...",
#   theme: "light" | "dark"
# }
class LandingPage < ApplicationRecord
  include SiteScoped

  belongs_to :site
  belongs_to :tenant

  # Validations
  validates :slug, presence: true, uniqueness: { scope: :site_id }
  validates :slug, format: { with: /\A[a-z0-9-]+\z/, message: "only allows lowercase letters, numbers, and hyphens" }
  validates :title, presence: true, length: { maximum: 255 }
  validates :headline, length: { maximum: 500 }
  validates :subheadline, length: { maximum: 2000 }
  validates :cta_text, length: { maximum: 100 }
  validates :cta_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true }

  # Scopes
  scope :published, -> { where(published: true) }
  scope :draft, -> { where(published: false) }
  scope :by_slug, ->(slug) { where(slug: slug) }

  # Content helpers
  def sections
    content["sections"] || []
  end

  def custom_css
    content["custom_css"]
  end

  def theme
    content["theme"] || "light"
  end

  def feature_sections
    sections.select { |s| s["type"] == "features" }
  end

  def testimonial_sections
    sections.select { |s| s["type"] == "testimonials" }
  end

  def faq_sections
    sections.select { |s| s["type"] == "faq" }
  end

  def listing_sections
    sections.select { |s| s["type"] == "listings" }
  end
end
