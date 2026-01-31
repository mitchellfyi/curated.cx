# frozen_string_literal: true

# == Schema Information
#
# Table name: live_stream_viewers
#
#  id               :bigint           not null, primary key
#  duration_seconds :integer
#  joined_at        :datetime         not null
#  left_at          :datetime
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  live_stream_id   :bigint           not null
#  session_id       :string
#  site_id          :bigint           not null
#  user_id          :bigint
#
# Indexes
#
#  index_live_stream_viewers_on_live_stream_id      (live_stream_id)
#  index_live_stream_viewers_on_site_id             (site_id)
#  index_live_stream_viewers_on_stream_and_session  (live_stream_id,session_id) UNIQUE WHERE (session_id IS NOT NULL)
#  index_live_stream_viewers_on_stream_and_user     (live_stream_id,user_id) UNIQUE WHERE (user_id IS NOT NULL)
#  index_live_stream_viewers_on_user_id             (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (live_stream_id => live_streams.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (user_id => users.id)
#
class LiveStreamViewer < ApplicationRecord
  include SiteScoped

  # Associations
  belongs_to :live_stream
  belongs_to :user, optional: true

  # Validations
  validates :joined_at, presence: true
  validate :must_have_user_or_session

  # Scopes
  scope :active, -> { where(left_at: nil) }
  scope :completed, -> { where.not(left_at: nil) }

  # Instance methods
  def active?
    left_at.nil?
  end

  def leave!
    return if left_at.present?

    update!(
      left_at: Time.current,
      duration_seconds: calculate_duration
    )
  end

  def calculate_duration
    return nil unless joined_at.present?

    end_time = left_at || Time.current
    (end_time - joined_at).to_i
  end

  private

  def must_have_user_or_session
    return if user_id.present? || session_id.present?

    errors.add(:base, "must have either a user or a session_id")
  end
end
