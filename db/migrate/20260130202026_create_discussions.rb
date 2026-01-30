# frozen_string_literal: true

class CreateDiscussions < ActiveRecord::Migration[8.1]
  def change
    create_table :discussions do |t|
      t.string :title, null: false
      t.text :body
      t.references :site, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :visibility, null: false, default: 0
      t.boolean :pinned, null: false, default: false
      t.datetime :pinned_at
      t.datetime :locked_at
      t.references :locked_by, foreign_key: { to_table: :users }
      t.integer :posts_count, null: false, default: 0
      t.datetime :last_post_at

      t.timestamps
    end

    add_index :discussions, %i[site_id visibility]
    add_index :discussions, %i[site_id pinned last_post_at]
    add_index :discussions, %i[site_id last_post_at]
  end
end
