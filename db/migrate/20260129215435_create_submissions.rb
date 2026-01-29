# frozen_string_literal: true

class CreateSubmissions < ActiveRecord::Migration[8.1]
  def change
    create_table :submissions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :site, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.references :listing, null: true, foreign_key: true

      t.text :url, null: false
      t.string :title, null: false
      t.text :description
      t.integer :listing_type, null: false, default: 0
      t.integer :status, null: false, default: 0

      t.text :reviewer_notes
      t.string :ip_address
      t.datetime :reviewed_at
      t.bigint :reviewed_by_id

      t.timestamps
    end

    add_index :submissions, :status
    add_index :submissions, [ :site_id, :status ]
    add_index :submissions, [ :user_id, :status ]
    add_index :submissions, :reviewed_by_id
    add_foreign_key :submissions, :users, column: :reviewed_by_id
  end
end
