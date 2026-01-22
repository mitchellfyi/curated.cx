# frozen_string_literal: true

class CreateSources < ActiveRecord::Migration[8.0]
  def change
    create_table :sources do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :site, null: false, foreign_key: true
      t.integer :kind, null: false
      t.string :name, null: false
      t.jsonb :config, default: {}, null: false
      t.jsonb :schedule, default: {}, null: false
      t.datetime :last_run_at
      t.string :last_status
      t.boolean :enabled, default: true, null: false

      t.timestamps
    end

    add_index :sources, [ :tenant_id, :name ], unique: true
    add_index :sources, [ :site_id, :name ], unique: true
    add_index :sources, [ :tenant_id, :kind ]
    add_index :sources, [ :tenant_id, :enabled ]
  end
end
