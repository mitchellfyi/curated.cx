# frozen_string_literal: true

class CreateSites < ActiveRecord::Migration[8.0]
  def change
    create_table :sites do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :slug, null: false
      t.string :name, null: false
      t.text :description
      t.jsonb :config, default: {}, null: false
      t.integer :status, default: 0, null: false # enum: enabled(0), disabled(1), private_access(2)

      t.timestamps
    end

    add_index :sites, [ :tenant_id, :slug ], unique: true
    add_index :sites, :status
    add_index :sites, [ :tenant_id, :status ]
  end
end
