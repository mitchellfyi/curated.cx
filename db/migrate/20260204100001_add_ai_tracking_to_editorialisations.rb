# frozen_string_literal: true

class AddAiTrackingToEditorialisations < ActiveRecord::Migration[8.1]
  def change
    # Add separate token tracking for input and output
    add_column :editorialisations, :input_tokens, :integer
    add_column :editorialisations, :output_tokens, :integer

    # Add cost tracking
    add_column :editorialisations, :estimated_cost_cents, :integer

    # Backfill existing records: assume tokens_used was total, split 70/30 as rough estimate
    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE editorialisations
          SET input_tokens = COALESCE(tokens_used * 0.7, 0)::integer,
              output_tokens = COALESCE(tokens_used * 0.3, 0)::integer
          WHERE tokens_used IS NOT NULL
        SQL
      end
    end

    # Add index for cost tracking queries
    add_index :editorialisations, [ :site_id, :created_at, :estimated_cost_cents ],
              name: "index_editorialisations_cost_tracking"
  end
end
