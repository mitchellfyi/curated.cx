# frozen_string_literal: true

class CreateSiteBans < ActiveRecord::Migration[8.0]
  def change
    create_table :site_bans do |t|
      t.references :site, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :banned_by, null: false, foreign_key: { to_table: :users }
      t.text :reason
      t.datetime :banned_at, null: false
      t.datetime :expires_at

      t.timestamps
    end

    # One ban per user per site
    add_index :site_bans, %i[site_id user_id], unique: true, name: "index_site_bans_uniqueness"
    # Active bans lookup (null expires_at OR expires_at > now)
    add_index :site_bans, %i[site_id expires_at], name: "index_site_bans_on_site_and_expires"
  end
end
