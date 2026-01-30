# frozen_string_literal: true

# == Schema Information
#
# Table name: digital_products
#
#  id             :bigint           not null, primary key
#  description    :text
#  download_count :integer          default(0), not null
#  metadata       :jsonb            not null
#  price_cents    :integer          default(0), not null
#  slug           :string           not null
#  status         :integer          default("draft"), not null
#  title          :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  site_id        :bigint           not null
#
# Indexes
#
#  index_digital_products_on_site_id             (site_id)
#  index_digital_products_on_site_id_and_slug    (site_id,slug) UNIQUE
#  index_digital_products_on_site_id_and_status  (site_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#
class DigitalProduct < ApplicationRecord
  include SiteScoped

  # File attachment
  has_one_attached :file

  # Associations
  has_many :purchases, dependent: :destroy

  # Enums
  enum :status, { draft: 0, published: 1, archived: 2 }, default: :draft

  # Validations
  validates :title, presence: true, length: { maximum: 255 }
  validates :slug, presence: true,
                   uniqueness: { scope: :site_id },
                   format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/, message: "must be lowercase with hyphens only" }
  validates :price_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :description, length: { maximum: 10_000 }, allow_blank: true
  validates :file, file_content_type: true, file_size: { max: 500.megabytes }, if: :file_attached?

  # Callbacks
  before_validation :generate_slug, on: :create, if: -> { slug.blank? && title.present? }

  # Scopes
  scope :visible, -> { published }
  scope :by_status, ->(status) { where(status: status) }
  scope :recent, -> { order(created_at: :desc) }

  # Instance methods
  def free?
    price_cents.zero?
  end

  def price_dollars
    price_cents / 100.0
  end

  def formatted_price
    free? ? "Free" : "$#{'%.2f' % price_dollars}"
  end

  def increment_download_count!
    increment!(:download_count)
  end

  def metadata
    super || {}
  end

  def file_attached?
    file.attached?
  end

  private

  def generate_slug
    base_slug = title.parameterize
    self.slug = base_slug

    counter = 1
    while self.class.unscoped.exists?(site_id: site_id, slug: slug)
      self.slug = "#{base_slug}-#{counter}"
      counter += 1
    end
  end
end
