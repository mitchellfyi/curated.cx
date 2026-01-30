# frozen_string_literal: true

# == Schema Information
#
# Table name: email_sequences
#
#  id             :bigint           not null, primary key
#  enabled        :boolean          default(FALSE), not null
#  name           :string           not null
#  trigger_config :jsonb
#  trigger_type   :integer          default("subscriber_joined"), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  site_id        :bigint           not null
#
# Indexes
#
#  index_email_sequences_on_site_id                               (site_id)
#  index_email_sequences_on_site_id_and_trigger_type_and_enabled  (site_id,trigger_type,enabled)
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#
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
