# frozen_string_literal: true

# == Schema Information
#
# Table name: import_runs
#
#  id            :bigint           not null, primary key
#  completed_at  :datetime
#  error_message :text
#  items_count   :integer          default(0)
#  items_created :integer          default(0)
#  items_failed  :integer          default(0)
#  items_updated :integer          default(0)
#  started_at    :datetime         not null
#  status        :integer          default("running"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  site_id       :bigint           not null
#  source_id     :bigint           not null
#
# Indexes
#
#  index_import_runs_on_site_id                   (site_id)
#  index_import_runs_on_site_id_and_started_at    (site_id,started_at)
#  index_import_runs_on_source_id                 (source_id)
#  index_import_runs_on_source_id_and_started_at  (source_id,started_at)
#  index_import_runs_on_status                    (status)
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (source_id => sources.id)
#
class ImportRun < ApplicationRecord
  include SiteScoped

  # Associations
  belongs_to :source

  # Enums
  enum :status, {
    running: 0,
    completed: 1,
    failed: 2
  }

  # Validations
  validates :started_at, presence: true
  validates :status, presence: true
  validates :items_count, :items_created, :items_updated, :items_failed,
            numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :recent, -> { order(started_at: :desc) }
  scope :by_source, ->(source) { where(source: source) }
  scope :completed, -> { where(status: :completed) }
  scope :failed, -> { where(status: :failed) }

  # Class methods
  def self.create_for_source!(source)
    create!(
      site: source.site,
      source: source,
      started_at: Time.current,
      status: :running
    )
  end

  # Instance methods
  def mark_completed!(items_created: 0, items_updated: 0, items_failed: 0)
    update!(
      status: :completed,
      completed_at: Time.current,
      items_created: items_created,
      items_updated: items_updated,
      items_failed: items_failed,
      items_count: items_created + items_updated + items_failed
    )
  end

  def mark_failed!(error_message)
    update!(
      status: :failed,
      completed_at: Time.current,
      error_message: error_message
    )
  end

  def duration
    return nil unless completed_at
    completed_at - started_at
  end

  def successful?
    completed? && items_failed == 0
  end
end
