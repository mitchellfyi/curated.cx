# frozen_string_literal: true

# == Schema Information
#
# Table name: submissions
#
#  id             :bigint           not null, primary key
#  description    :text
#  ip_address     :string
#  listing_type   :integer          default("tool"), not null
#  reviewed_at    :datetime
#  reviewer_notes :text
#  status         :integer          default("pending"), not null
#  title          :string           not null
#  url            :text             not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  category_id    :bigint           not null
#  entry_id       :bigint
#  reviewed_by_id :bigint
#  site_id        :bigint           not null
#  user_id        :bigint           not null
#
# Indexes
#
#  index_submissions_on_category_id         (category_id)
#  index_submissions_on_entry_id            (entry_id)
#  index_submissions_on_reviewed_by_id      (reviewed_by_id)
#  index_submissions_on_site_id             (site_id)
#  index_submissions_on_site_id_and_status  (site_id,status)
#  index_submissions_on_status              (status)
#  index_submissions_on_user_id             (user_id)
#  index_submissions_on_user_id_and_status  (user_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (category_id => categories.id)
#  fk_rails_...  (entry_id => entries.id)
#  fk_rails_...  (reviewed_by_id => users.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (user_id => users.id)
#
class Submission < ApplicationRecord
  include SiteScoped

  # Associations
  belongs_to :user
  belongs_to :site
  belongs_to :category
  belongs_to :entry, optional: true
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

  # Mark as approved and create entry (directory)
  def approve!(reviewer:, notes: nil)
    transaction do
      entry = create_entry!
      update!(
        status: :approved,
        reviewer: reviewer,
        reviewer_notes: notes,
        reviewed_at: Time.current,
        entry: entry
      )
      entry
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

  # Create a directory entry from this submission
  def create_entry!
    Entry.create!(
      site: site,
      tenant: site.tenant,
      category: category,
      entry_kind: "directory",
      url_raw: url,
      url_canonical: url,
      domain: URI.parse(url).host,
      title: title,
      description: description,
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
