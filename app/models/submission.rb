# frozen_string_literal: true

class Submission < ApplicationRecord
  include SiteScoped

  # Associations
  belongs_to :user
  belongs_to :site
  belongs_to :category
  belongs_to :listing, optional: true
  belongs_to :reviewer, class_name: "User", foreign_key: :reviewed_by_id, optional: true

  # Enums
  enum :status, { pending: 0, approved: 1, rejected: 2 }, default: :pending
  enum :listing_type, { tool: 0, job: 1, service: 2 }, default: :tool

  # Validations
  validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }
  validates :title, presence: true, length: { maximum: 255 }
  validates :description, length: { maximum: 2000 }, allow_blank: true
  validates :listing_type, presence: true
  validates :status, presence: true

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :needs_review, -> { pending.order(created_at: :asc) }
  scope :by_user, ->(user) { where(user: user) }

  # Callbacks
  before_validation :normalize_url, on: :create

  # Mark as approved and create listing
  def approve!(reviewer:, notes: nil)
    transaction do
      listing = create_listing!
      update!(
        status: :approved,
        reviewer: reviewer,
        reviewer_notes: notes,
        reviewed_at: Time.current,
        listing: listing
      )
      listing
    end
  end

  # Mark as rejected
  def reject!(reviewer:, notes: nil)
    update!(
      status: :rejected,
      reviewer: reviewer,
      reviewer_notes: notes,
      reviewed_at: Time.current
    )
  end

  # Create a listing from this submission
  def create_listing!
    Listing.create!(
      site: site,
      tenant: site.tenant,
      category: category,
      url_raw: url,
      url_canonical: url,
      domain: URI.parse(url).host,
      title: title,
      description: description,
      listing_type: listing_type,
      published_at: Time.current
    )
  end

  private

  def normalize_url
    return if url.blank?

    self.url = url.strip
    self.url = "https://#{url}" unless url.start_with?("http://", "https://")
  end
end
