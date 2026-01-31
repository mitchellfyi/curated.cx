# frozen_string_literal: true

# == Schema Information
#
# Table name: live_streams
#
#  id                 :bigint           not null, primary key
#  description        :text
#  ended_at           :datetime
#  peak_viewers       :integer          default(0), not null
#  scheduled_at       :datetime         not null
#  started_at         :datetime
#  status             :integer          default("scheduled"), not null
#  stream_key         :string
#  title              :string           not null
#  viewer_count       :integer          default(0), not null
#  visibility         :integer          default("public_access"), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  discussion_id      :bigint
#  mux_asset_id       :string
#  mux_playback_id    :string
#  mux_stream_id      :string
#  replay_playback_id :string
#  site_id            :bigint           not null
#  user_id            :bigint           not null
#
# Indexes
#
#  index_live_streams_on_discussion_id             (discussion_id)
#  index_live_streams_on_mux_stream_id             (mux_stream_id) UNIQUE
#  index_live_streams_on_site_id                   (site_id)
#  index_live_streams_on_site_id_and_scheduled_at  (site_id,scheduled_at)
#  index_live_streams_on_site_id_and_status        (site_id,status)
#  index_live_streams_on_user_id                   (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (discussion_id => discussions.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (user_id => users.id)
#
class LiveStream < ApplicationRecord
  include SiteScoped

  # Maximum lengths
  TITLE_MAX_LENGTH = 200
  DESCRIPTION_MAX_LENGTH = 5_000

  # Enums - using prefix to avoid conflict with ActiveRecord methods
  enum :status, { scheduled: 0, live: 1, ended: 2, archived: 3 }, prefix: :status
  enum :visibility, { public_access: 0, subscribers_only: 1 }, prefix: :visibility

  # Associations
  belongs_to :user
  belongs_to :discussion, optional: true
  has_many :viewers, class_name: "LiveStreamViewer", dependent: :destroy

  # Validations
  validates :title, presence: true, length: { maximum: TITLE_MAX_LENGTH }
  validates :description, length: { maximum: DESCRIPTION_MAX_LENGTH }, allow_blank: true
  validates :scheduled_at, presence: true
  validates :status, presence: true
  validates :visibility, presence: true

  # Scopes
  scope :upcoming, -> { where(status: :scheduled).where("scheduled_at > ?", Time.current).order(scheduled_at: :asc) }
  scope :live_now, -> { where(status: :live) }
  scope :past, -> { where(status: %i[ended archived]).order(ended_at: :desc) }
  scope :publicly_visible, -> { where(visibility: :public_access) }

  # Instance methods
  def live?
    status_live?
  end

  def can_start?
    status_scheduled?
  end

  def can_end?
    status_live?
  end

  def start!
    return false unless can_start?

    update!(status: :live, started_at: Time.current)
  end

  def end!
    return false unless can_end?

    update!(status: :ended, ended_at: Time.current)
  end

  def archive!
    return false unless status_ended?

    update!(status: :archived)
  end

  def replay_available?
    (status_ended? || status_archived?) && replay_playback_id.present?
  end

  def replay_url
    return nil unless replay_available?

    "https://stream.mux.com/#{replay_playback_id}.m3u8"
  end

  def playback_url
    return nil unless mux_playback_id.present?

    "https://stream.mux.com/#{mux_playback_id}.m3u8"
  end

  def update_peak_viewers!
    current_count = viewers.where(left_at: nil).count
    update!(peak_viewers: current_count) if current_count > peak_viewers
  end

  def refresh_viewer_count!
    update!(viewer_count: viewers.where(left_at: nil).count)
  end
end
