# frozen_string_literal: true

class CreateDiscussionPosts < ActiveRecord::Migration[8.1]
  def change
    create_table :discussion_posts do |t|
      t.references :discussion, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :site, null: false, foreign_key: true
      t.text :body, null: false
      t.references :parent, foreign_key: { to_table: :discussion_posts }
      t.datetime :edited_at
      t.datetime :hidden_at

      t.timestamps
    end

    add_index :discussion_posts, %i[discussion_id created_at]
    add_index :discussion_posts, %i[site_id user_id]
  end
end
