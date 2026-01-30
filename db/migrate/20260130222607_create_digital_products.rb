# frozen_string_literal: true

class CreateDigitalProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :digital_products do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.text :description
      t.integer :price_cents, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.integer :download_count, null: false, default: 0
      t.jsonb :metadata, null: false, default: {}
      t.references :site, null: false, foreign_key: true

      t.timestamps
    end

    add_index :digital_products, %i[site_id slug], unique: true
    add_index :digital_products, %i[site_id status]
  end
end
