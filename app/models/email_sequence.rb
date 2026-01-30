# frozen_string_literal: true

class EmailSequence < ApplicationRecord
  include SiteScoped

  # Associations
  has_many :email_steps, dependent: :destroy
  has_many :sequence_enrollments, dependent: :destroy

  # Enums
  enum :trigger_type, { subscriber_joined: 0, referral_milestone: 1 }, default: :subscriber_joined

  # Validations
  validates :name, presence: true, uniqueness: { scope: :site_id }
  validates :trigger_type, presence: true

  # Scopes
  scope :enabled, -> { where(enabled: true) }
  scope :for_trigger, ->(trigger) { where(trigger_type: trigger) }

  # Returns trigger config with indifferent access
  def trigger_config
    (super || {}).with_indifferent_access
  end
end
