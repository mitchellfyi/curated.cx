# frozen_string_literal: true

class CreateWorkflowPauses < ActiveRecord::Migration[8.1]
  def change
    create_table :workflow_pauses do |t|
      t.references :tenant, null: true, foreign_key: true  # null = global pause
      t.string :workflow_type, null: false  # imports, ai_processing
      t.string :workflow_subtype  # rss, serp_api_google_news, etc.
      t.references :source, null: true, foreign_key: true  # for source-specific pauses
      t.boolean :paused, default: false, null: false
      t.datetime :paused_at
      t.datetime :resumed_at
      t.references :paused_by, foreign_key: { to_table: :users }
      t.text :reason

      t.timestamps
    end

    add_index :workflow_pauses, [:tenant_id, :workflow_type, :workflow_subtype], 
              name: 'idx_workflow_pauses_lookup'
    add_index :workflow_pauses, [:workflow_type, :paused], 
              name: 'idx_workflow_pauses_active'
  end
end
