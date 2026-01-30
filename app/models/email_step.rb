# frozen_string_literal: true

# == Schema Information
#
# Table name: email_steps
#
#  id                :bigint           not null, primary key
#  body_html         :text             not null
#  body_text         :text
#  delay_seconds     :integer          default(0), not null
#  position          :integer          default(0), not null
#  subject           :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  email_sequence_id :bigint           not null
#
# Indexes
#
#  index_email_steps_on_email_sequence_id               (email_sequence_id)
#  index_email_steps_on_email_sequence_id_and_position  (email_sequence_id,position) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (email_sequence_id => email_sequences.id)
#
class EmailStep < ApplicationRecord
  # Associations
  belongs_to :email_sequence
  has_many :sequence_emails, dependent: :destroy

  # Validations
  validates :subject, presence: true
  validates :body_html, presence: true
  validates :position, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :delay_seconds, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :ordered, -> { order(position: :asc) }

  # Returns delay as ActiveSupport::Duration
  def delay_duration
    delay_seconds.seconds
  end
end
