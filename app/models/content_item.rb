# frozen_string_literal: true

# == Schema Information
#
# Table name: content_items
#
#  id                    :bigint           not null, primary key
#  ai_suggested_tags     :jsonb            not null
#  ai_summary            :text
#  comments_count        :integer          default(0), not null
#  comments_locked_at    :datetime
#  content_type          :string
#  description           :text
#  editorialised_at      :datetime
#  extracted_text        :text
#  hidden_at             :datetime
#  published_at          :datetime
#  raw_payload           :jsonb            not null
#  summary               :text
#  tagging_confidence    :decimal(3, 2)
#  tagging_explanation   :jsonb            not null
#  tags                  :jsonb            not null
#  title                 :string
#  topic_tags            :jsonb            not null
#  upvotes_count         :integer          default(0), not null
#  url_canonical         :string           not null
#  url_raw               :text             not null
#  why_it_matters        :text
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  comments_locked_by_id :bigint
#  hidden_by_id          :bigint
#  site_id               :bigint           not null
#  source_id             :bigint           not null
#
# Indexes
#
#  index_content_items_on_comments_locked_by_id         (comments_locked_by_id)
#  index_content_items_on_hidden_at                     (hidden_at)
#  index_content_items_on_hidden_by_id                  (hidden_by_id)
#  index_content_items_on_published_at                  (published_at)
#  index_content_items_on_site_id                       (site_id)
#  index_content_items_on_site_id_and_content_type      (site_id,content_type)
#  index_content_items_on_site_id_and_editorialised_at  (site_id,editorialised_at)
#  index_content_items_on_site_id_and_url_canonical     (site_id,url_canonical) UNIQUE
#  index_content_items_on_site_id_published_at_desc     (site_id,published_at DESC)
#  index_content_items_on_source_id                     (source_id)
#  index_content_items_on_source_id_and_created_at      (source_id,created_at)
#  index_content_items_on_topic_tags_gin                (topic_tags) USING gin
#
# Foreign Keys
#
#  fk_rails_...  (comments_locked_by_id => users.id)
#  fk_rails_...  (hidden_by_id => users.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (source_id => sources.id)
#
class ContentItem < ApplicationRecord
  include SiteScoped
  include PgSearch::Model

  # Full-text search
  pg_search_scope :search_content,
    against: {
      title: "A",
      description: "B",
      ai_summary: "C"
    },
    using: {
      tsearch: { prefix: true, dictionary: "english" }
    }

  # Associations
  belongs_to :source
  has_many :votes, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :flags, as: :flaggable, dependent: :destroy
  belongs_to :hidden_by, class_name: "User", optional: true
  belongs_to :comments_locked_by, class_name: "User", optional: true

  # Validations
  validates :url_canonical, presence: true, uniqueness: { scope: :site_id }
  validates :url_raw, presence: true
  validates :raw_payload, presence: true
  validates :tags, presence: true

  # Callbacks
  before_validation :normalize_url_canonical
  before_validation :ensure_tags_is_array
  after_create :apply_tagging_rules
  after_create :enqueue_editorialisation

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_source, ->(source) { where(source: source) }
  scope :published, -> { where.not(published_at: nil) }
  scope :unpublished, -> { where(published_at: nil) }
  scope :by_content_type, ->(type) { where(content_type: type) }
  scope :tagged_with, ->(taxonomy_slug) { where("topic_tags @> ?", [ taxonomy_slug ].to_json) }

  # Feed scopes
  scope :not_hidden, -> { where(hidden_at: nil) }
  scope :for_feed, -> { published.not_hidden.order(published_at: :desc) }
  scope :published_since, ->(time) { published.where("published_at >= ?", time) }
  scope :top_this_week, -> { published_since(1.week.ago).order(Arel.sql("(upvotes_count + comments_count) DESC, published_at DESC")) }
  scope :by_engagement, -> { order(Arel.sql("(upvotes_count + comments_count) DESC")) }

  # Class methods
  # Find or initialize by canonical URL (for deduplication)
  def self.find_or_initialize_by_canonical_url(site:, url_canonical:, source:)
    find_or_initialize_by(site: site, url_canonical: url_canonical) do |item|
      item.source = source
      item.url_raw = url_canonical # Default to canonical if raw not provided
    end
  end

  # Instance methods
  def raw_payload
    super || {}
  end

  def tags
    super || []
  end

  def published?
    published_at.present?
  end

  def topic_tags
    super || []
  end

  def tagging_explanation
    super || []
  end

  def ai_summary
    super
  end

  def ai_suggested_tags
    super || []
  end

  # Check if this item has been editorialised
  def editorialised?
    editorialised_at.present?
  end

  # Moderation methods
  def hidden?
    hidden_at.present?
  end

  def comments_locked?
    comments_locked_at.present?
  end

  def hide!(user)
    update!(hidden_at: Time.current, hidden_by: user)
  end

  def unhide!
    update!(hidden_at: nil, hidden_by: nil)
  end

  def lock_comments!(user)
    update!(comments_locked_at: Time.current, comments_locked_by: user)
  end

  def unlock_comments!
    update!(comments_locked_at: nil, comments_locked_by: nil)
  end

  private

  def apply_tagging_rules
    result = TaggingService.tag(self)
    update_columns(
      topic_tags: result[:topic_tags],
      content_type: result[:content_type],
      tagging_confidence: result[:confidence],
      tagging_explanation: result[:explanation]
    )
  end

  def normalize_url_canonical
    return unless url_canonical.present?
    # Use UrlCanonicaliser to normalize the canonical URL
    # This ensures consistent format even if caller passes already-canonicalized URL
    normalized = UrlCanonicaliser.canonicalize(url_canonical)
    self.url_canonical = normalized
  rescue UrlCanonicaliser::InvalidUrlError => e
    errors.add(:url_canonical, e.message)
  rescue StandardError => e
    # If canonicalization fails, log but don't fail validation (raw URL is stored)
    Rails.logger.warn("URL canonicalization failed for #{url_canonical}: #{e.message}")
  end

  def ensure_tags_is_array
    self.tags = [] unless tags.is_a?(Array)
  end

  def enqueue_editorialisation
    return unless source&.editorialisation_enabled?

    EditorialiseContentItemJob.perform_later(id)
  end
end
