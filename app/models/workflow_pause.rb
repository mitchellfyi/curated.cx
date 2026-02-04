# frozen_string_literal: true

# Tracks workflow pause states for tenant-level and global control.
# Allows admins to pause imports, AI processing, etc.
#
# == Schema Information
#
# Table name: workflow_pauses
#
#  id               :bigint           not null, primary key
#  paused           :boolean          default(FALSE), not null
#  paused_at        :datetime
#  reason           :text
#  resumed_at       :datetime
#  workflow_subtype :string
#  workflow_type    :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  paused_by_id     :bigint
#  source_id        :bigint
#  tenant_id        :bigint
#
class WorkflowPause < ApplicationRecord
  WORKFLOW_TYPES = %w[imports ai_processing rss_ingestion serp_api_ingestion editorialisation all_ingestion].freeze

  # Associations
  belongs_to :tenant, optional: true  # nil = global pause
  belongs_to :source, optional: true  # for source-specific pauses
  belongs_to :paused_by, class_name: "User"
  belongs_to :resumed_by, class_name: "User", optional: true

  # Validations
  validates :workflow_type, presence: true
  validates :workflow_type, inclusion: { in: WORKFLOW_TYPES }
  validates :paused_at, presence: true
  validates :paused_by, presence: true
  validates :workflow_subtype, inclusion: {
    in: %w[rss serp_api_google_news serp_api_google_jobs serp_api_youtube all],
    allow_nil: true
  }

  # Scopes
  scope :active, -> { where(resumed_at: nil) }
  scope :resolved, -> { where.not(resumed_at: nil) }
  scope :global, -> { where(tenant_id: nil) }
  scope :for_tenant, ->(tenant) { where(tenant: tenant) }
  scope :for_workflow, ->(type) { where(workflow_type: type) }
  scope :for_subtype, ->(subtype) { where(workflow_subtype: [ subtype, "all", nil ]) }
  scope :recent, -> { order(created_at: :desc) }

  # Class methods
  def self.paused?(workflow_type, tenant: nil, source: nil, subtype: nil)
    # Check global pause first
    return true if global.for_workflow(workflow_type).for_subtype(subtype).active.exists?

    # Check tenant-specific pause
    if tenant
      return true if for_tenant(tenant).for_workflow(workflow_type).for_subtype(subtype).active.exists?
    end

    # Check source-specific pause
    if source
      return true if where(source: source).active.exists?
    end

    false
  end

  def self.find_active(workflow_type, tenant: nil, source: nil, subtype: nil)
    # Find the most specific active pause for this context
    # Priority: source-specific > tenant-specific > global
    scope = active.for_workflow(workflow_type.to_s)

    if source
      pause = scope.where(source: source).first
      return pause if pause
    end

    if tenant
      pause = scope.for_tenant(tenant).for_subtype(subtype).first
      return pause if pause
    end

    # Return global pause if any
    scope.global.for_subtype(subtype).first
  end

  def self.find_or_create_for(workflow_type:, tenant: nil, subtype: nil, source: nil)
    find_or_create_by!(
      workflow_type: workflow_type,
      workflow_subtype: subtype,
      tenant: tenant,
      source: source
    )
  end

  # Instance methods
  def pause!(by:, reason: nil)
    update!(
      paused_at: Time.current,
      resumed_at: nil,
      paused_by: by,
      reason: reason
    )
  end

  def resume!(by:)
    update!(
      resumed_at: Time.current,
      resumed_by: by
    )
  end

  def global?
    tenant_id.nil?
  end

  def active?
    resumed_at.nil?
  end

  def duration_text
    return nil unless paused_at

    seconds = if resumed_at
      resumed_at - paused_at
    else
      Time.current - paused_at
    end

    if seconds < 60
      "#{seconds.to_i}s"
    elsif seconds < 3600
      "#{(seconds / 60).to_i}m"
    elsif seconds < 86400
      "#{(seconds / 3600).to_i}h"
    else
      "#{(seconds / 86400).to_i}d"
    end
  end

  def scope_description
    type_name = workflow_type.to_s.titleize
    scope = if source
      "Source: #{source.name}"
    elsif tenant
      tenant.name
    else
      "(global)"
    end
    "#{type_name} - #{scope}"
  end
end
