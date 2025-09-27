# frozen_string_literal: true

class CreateTenants < ActiveRecord::Migration[8.0]
  def change
    create_table :tenants do |t|
      t.string :hostname, null: false
      t.string :slug, null: false
      t.string :title, null: false
      t.text :description
      t.string :logo_url
      t.jsonb :settings, default: {}, null: false
      t.integer :status, default: 0, null: false # enum: enabled(0), disabled(1), private_access(2)

      t.timestamps
    end

    add_index :tenants, :hostname, unique: true
    add_index :tenants, :slug, unique: true
    add_index :tenants, :status
  end
end
