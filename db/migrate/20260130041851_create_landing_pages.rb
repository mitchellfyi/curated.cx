class CreateLandingPages < ActiveRecord::Migration[8.1]
  def change
    create_table :landing_pages do |t|
      t.string :slug, null: false
      t.string :title, null: false
      t.string :headline
      t.text :subheadline
      t.string :cta_text
      t.string :cta_url
      t.string :hero_image_url
      t.jsonb :content, default: {}, null: false
      t.boolean :published, default: false, null: false
      t.references :site, null: false, foreign_key: true
      t.references :tenant, null: false, foreign_key: true

      t.timestamps
    end
    add_index :landing_pages, [ :site_id, :slug ], unique: true
    add_index :landing_pages, [ :site_id, :published ]
  end
end
