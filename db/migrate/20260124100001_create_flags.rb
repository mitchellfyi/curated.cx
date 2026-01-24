# frozen_string_literal: true

class CreateFlags < ActiveRecord::Migration[8.0]
  def change
    create_table :flags do |t|
      t.references :site, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :flaggable, polymorphic: true, null: false
      t.integer :reason, null: false, default: 0
      t.text :details
      t.integer :status, null: false, default: 0
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.datetime :reviewed_at

      t.timestamps
    end

    # One flag per user per flaggable item within a site
    add_index :flags, %i[site_id user_id flaggable_type flaggable_id],
              unique: true, name: "index_flags_uniqueness"
    # Pending flags queue lookup
    add_index :flags, %i[site_id status], name: "index_flags_on_site_and_status"
    # Flaggable lookup (already created by polymorphic: true)
  end
end
