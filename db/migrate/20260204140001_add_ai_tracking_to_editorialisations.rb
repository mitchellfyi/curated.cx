# frozen_string_literal: true

class AddAiTrackingToEditorialisations < ActiveRecord::Migration[8.1]
  def change
    # More granular token tracking
    add_column :editorialisations, :input_tokens, :integer
    add_column :editorialisations, :output_tokens, :integer
    
    # Cost tracking in cents for precision
    add_column :editorialisations, :estimated_cost_cents, :integer

    # Backfill: split existing tokens_used roughly 70/30 (input heavy for summaries)
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE editorialisations
          SET input_tokens = COALESCE(tokens_used * 7 / 10, 0),
              output_tokens = COALESCE(tokens_used * 3 / 10, 0)
          WHERE tokens_used IS NOT NULL
        SQL
      end
    end
  end
end
