# frozen_string_literal: true

class CreateComments < ActiveRecord::Migration[8.0]
  def change
    create_table :comments do |t|
      t.references :site, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :content_item, null: false, foreign_key: true
      t.references :parent, foreign_key: { to_table: :comments }
      t.text :body, null: false
      t.datetime :edited_at

      t.timestamps
    end

    # Index for retrieving comments by content_item and parent (threaded queries)
    add_index :comments, %i[content_item_id parent_id], name: "index_comments_on_content_item_and_parent"
    # Index for retrieving user's comments
    add_index :comments, %i[site_id user_id], name: "index_comments_on_site_and_user"
  end
end
