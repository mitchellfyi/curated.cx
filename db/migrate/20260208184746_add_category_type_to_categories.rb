class AddCategoryTypeToCategories < ActiveRecord::Migration[8.1]
  def change
    add_column :categories, :category_type, :string, default: "article", null: false
    add_column :categories, :display_template, :string
    add_column :categories, :metadata_schema, :jsonb, default: {}, null: false

    add_index :categories, [ :site_id, :category_type ], name: "index_categories_on_site_id_and_category_type"
  end
end
