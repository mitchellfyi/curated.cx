# frozen_string_literal: true

class CreateWorkflowPauses < ActiveRecord::Migration[8.1]
  def change
    create_table :workflow_pauses do |t|
      # Workflow type being paused (e.g., "rss_ingestion", "serp_api", "editorialisation")
      t.string :workflow_type, null: false

      # Tenant scoping - nil means global pause (super admin only)
      t.references :tenant, foreign_key: true, null: true

      # Source-specific pause (optional)
      t.references :source, foreign_key: true, null: true

      # Who paused it
      t.references :paused_by, foreign_key: { to_table: :users }, null: false

      # Pause metadata
      t.text :reason
      t.datetime :paused_at, null: false
      t.datetime :resumed_at

      # Who resumed it (nullable until resumed)
      t.references :resumed_by, foreign_key: { to_table: :users }, null: true

      t.timestamps
    end

    # Unique constraint: only one active pause per workflow_type + tenant + source combination
    add_index :workflow_pauses, [ :workflow_type, :tenant_id, :source_id ],
              unique: true,
              where: "resumed_at IS NULL",
              name: "index_workflow_pauses_active_unique"

    # Index for finding active pauses quickly
    add_index :workflow_pauses, [ :workflow_type, :tenant_id ],
              where: "resumed_at IS NULL",
              name: "index_workflow_pauses_active_by_type_tenant"

    # Index for history queries
    add_index :workflow_pauses, [ :workflow_type, :paused_at ],
              name: "index_workflow_pauses_history"
  end
end
