# frozen_string_literal: true

# == Schema Information
#
# Table name: subscriber_segments
#
#  id             :bigint           not null, primary key
#  description    :text
#  enabled        :boolean          default(TRUE), not null
#  name           :string           not null
#  rules          :jsonb            not null
#  system_segment :boolean          default(FALSE), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  site_id        :bigint           not null
#  tenant_id      :bigint           not null
#
# Indexes
#
#  index_subscriber_segments_on_site_id                     (site_id)
#  index_subscriber_segments_on_site_id_and_enabled         (site_id,enabled)
#  index_subscriber_segments_on_site_id_and_system_segment  (site_id,system_segment)
#  index_subscriber_segments_on_tenant_id                   (tenant_id)
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
class SubscriberSegment < ApplicationRecord
  include SiteScoped

  # Associations
  belongs_to :tenant

  # Validations
  validates :name, presence: true, length: { maximum: 100 }

  # Scopes
  scope :enabled, -> { where(enabled: true) }
  scope :system, -> { where(system_segment: true) }
  scope :custom, -> { where(system_segment: false) }

  def rules
    super || {}
  end

  def editable?
    !system_segment?
  end

  def subscribers_count
    SegmentationService.subscribers_for(self).count
  end
end
