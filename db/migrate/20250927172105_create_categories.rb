class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :key, null: false
      t.string :name, null: false
      t.boolean :allow_paths, default: true, null: false
      t.jsonb :shown_fields, default: {}, null: false

      t.timestamps
    end

    add_index :categories, [:tenant_id, :key], unique: true
  end
end
