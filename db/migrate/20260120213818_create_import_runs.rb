# frozen_string_literal: true

class CreateImportRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :import_runs do |t|
      t.references :site, null: false, foreign_key: true
      t.references :source, null: false, foreign_key: true
      t.datetime :started_at, null: false
      t.datetime :completed_at
      t.integer :status, default: 0, null: false # enum: running, completed, failed
      t.text :error_message
      t.integer :items_count, default: 0
      t.integer :items_created, default: 0
      t.integer :items_updated, default: 0
      t.integer :items_failed, default: 0

      t.timestamps
    end

    add_index :import_runs, [ :site_id, :started_at ]
    add_index :import_runs, [ :source_id, :started_at ]
    add_index :import_runs, :status
  end
end
