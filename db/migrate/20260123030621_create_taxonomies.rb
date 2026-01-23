# frozen_string_literal: true

class CreateTaxonomies < ActiveRecord::Migration[8.0]
  def change
    create_table :taxonomies do |t|
      t.references :site, null: false, foreign_key: true
      t.references :tenant, null: false, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.bigint :parent_id
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :taxonomies, %i[site_id slug], unique: true
    add_index :taxonomies, %i[site_id parent_id]
    add_foreign_key :taxonomies, :taxonomies, column: :parent_id
  end
end
