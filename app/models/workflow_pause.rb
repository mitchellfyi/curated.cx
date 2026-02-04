# frozen_string_literal: true

# Tracks workflow pauses for cost control and maintenance.
# Pauses can be:
# - Global (tenant_id: nil) - affects all tenants, super admin only
# - Tenant-specific (tenant_id present) - affects only that tenant
# - Source-specific (source_id present) - affects only that source
#
# == Schema Information
#
# Table name: workflow_pauses
#
#  id            :bigint           not null, primary key
#  paused_at     :datetime         not null
#  reason        :text
#  resumed_at    :datetime
#  workflow_type :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  paused_by_id  :bigint           not null
#  resumed_by_id :bigint
#  source_id     :bigint
#  tenant_id     :bigint
#
# Indexes
#
#  index_workflow_pauses_active_by_type_tenant  (workflow_type,tenant_id) WHERE (resumed_at IS NULL)
#  index_workflow_pauses_active_unique          (workflow_type,tenant_id,source_id) UNIQUE WHERE (resumed_at IS NULL)
#  index_workflow_pauses_history                (workflow_type,paused_at)
#
# Foreign Keys
#
#  fk_rails_...  (paused_by_id => users.id)
#  fk_rails_...  (resumed_by_id => users.id)
#  fk_rails_...  (source_id => sources.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
class WorkflowPause < ApplicationRecord
  # Known workflow types
  WORKFLOW_TYPES = %w[
    rss_ingestion
    serp_api_ingestion
    editorialisation
    all_ingestion
  ].freeze

  # Associations
  belongs_to :tenant, optional: true
  belongs_to :source, optional: true
  belongs_to :paused_by, class_name: "User"
  belongs_to :resumed_by, class_name: "User", optional: true

  # Validations
  validates :workflow_type, presence: true, inclusion: { in: WORKFLOW_TYPES }
  validates :paused_at, presence: true
  validates :paused_by, presence: true
  validate :source_belongs_to_tenant, if: -> { source.present? && tenant.present? }

  # Scopes
  scope :active, -> { where(resumed_at: nil) }
  scope :resolved, -> { where.not(resumed_at: nil) }
  scope :recent, -> { order(paused_at: :desc) }
  scope :for_tenant, ->(tenant) { where(tenant: tenant) }
  scope :global, -> { where(tenant_id: nil) }
  scope :for_workflow, ->(type) { where(workflow_type: type) }
  scope :for_source, ->(source) { where(source: source) }

  # Class methods

  # Check if a workflow is currently paused
  # Checks in order: source-specific, tenant-specific, global
  def self.paused?(workflow_type, tenant: nil, source: nil)
    # Check source-specific pause
    if source.present?
      return true if active.for_workflow(workflow_type).for_source(source).exists?
    end

    # Check tenant-specific pause
    if tenant.present?
      return true if active.for_workflow(workflow_type).for_tenant(tenant).where(source_id: nil).exists?
      # Also check "all_ingestion" for ingestion workflows
      if workflow_type.include?("ingestion")
        return true if active.for_workflow("all_ingestion").for_tenant(tenant).where(source_id: nil).exists?
      end
    end

    # Check global pause
    return true if active.for_workflow(workflow_type).global.where(source_id: nil).exists?
    return true if workflow_type.include?("ingestion") && active.for_workflow("all_ingestion").global.where(source_id: nil).exists?

    false
  end

  # Find the active pause for a workflow (returns most specific)
  def self.find_active(workflow_type, tenant: nil, source: nil)
    # Try source-specific first
    if source.present?
      pause = active.for_workflow(workflow_type).for_source(source).first
      return pause if pause
    end

    # Try tenant-specific
    if tenant.present?
      pause = active.for_workflow(workflow_type).for_tenant(tenant).where(source_id: nil).first
      return pause if pause

      # Check all_ingestion for ingestion workflows
      if workflow_type.include?("ingestion")
        pause = active.for_workflow("all_ingestion").for_tenant(tenant).where(source_id: nil).first
        return pause if pause
      end
    end

    # Try global
    pause = active.for_workflow(workflow_type).global.where(source_id: nil).first
    return pause if pause

    # Check global all_ingestion
    if workflow_type.include?("ingestion")
      active.for_workflow("all_ingestion").global.where(source_id: nil).first
    end
  end

  # Instance methods

  def active?
    resumed_at.nil?
  end

  def resolved?
    resumed_at.present?
  end

  def global?
    tenant_id.nil?
  end

  def source_specific?
    source_id.present?
  end

  def duration
    return nil unless active?

    Time.current - paused_at
  end

  def duration_text
    seconds = duration || (resumed_at - paused_at)
    return "just now" if seconds < 60

    parts = []
    days = (seconds / 1.day).floor
    hours = ((seconds % 1.day) / 1.hour).floor
    minutes = ((seconds % 1.hour) / 1.minute).floor

    parts << "#{days}d" if days > 0
    parts << "#{hours}h" if hours > 0
    parts << "#{minutes}m" if minutes > 0

    parts.join(" ")
  end

  def resume!(by:)
    update!(
      resumed_at: Time.current,
      resumed_by: by
    )
  end

  def scope_description
    parts = [workflow_type.titleize]
    parts << "for #{tenant.name}" if tenant.present?
    parts << "(source: #{source.name})" if source.present?
    parts << "(global)" if global?
    parts.join(" ")
  end

  private

  def source_belongs_to_tenant
    return unless source.tenant_id != tenant_id

    errors.add(:source, "must belong to the specified tenant")
  end
end
