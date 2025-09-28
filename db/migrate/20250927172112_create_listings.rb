class CreateListings < ActiveRecord::Migration[8.0]
  def change
    create_table :listings do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.text :url_raw, null: false
      t.text :url_canonical, null: false
      t.string :domain
      t.string :title
      t.text :description
      t.text :image_url
      t.string :site_name
      t.datetime :published_at
      t.text :body_html
      t.text :body_text
      t.jsonb :ai_summaries, default: {}, null: false
      t.jsonb :ai_tags, default: {}, null: false
      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end

    add_index :listings, [ :tenant_id, :url_canonical ], unique: true, name: 'index_listings_on_tenant_and_url_canonical'
    add_index :listings, [ :tenant_id, :category_id ]
    add_index :listings, :domain
    add_index :listings, :published_at
  end
end
