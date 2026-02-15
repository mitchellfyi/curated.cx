# frozen_string_literal: true

class CreateSponsorships < ActiveRecord::Migration[8.0]
  def change
    create_table :sponsorships do |t|
      t.references :site, null: false, foreign_key: true
      t.references :entry, null: true, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :placement_type, null: false
      t.string :category_slug
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.integer :budget_cents, default: 0, null: false
      t.integer :spent_cents, default: 0, null: false
      t.integer :impressions, default: 0, null: false
      t.integer :clicks, default: 0, null: false
      t.string :status, default: "pending", null: false

      t.timestamps
    end

    add_index :sponsorships, :placement_type
    add_index :sponsorships, :status
    add_index :sponsorships, [ :site_id, :status ]
    add_index :sponsorships, [ :starts_at, :ends_at ]
  end
end
