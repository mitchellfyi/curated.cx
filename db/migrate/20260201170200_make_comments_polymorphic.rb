# frozen_string_literal: true

class MakeCommentsPolymorphic < ActiveRecord::Migration[8.0]
  def up
    # Add polymorphic columns
    add_column :comments, :commentable_type, :string
    add_column :comments, :commentable_id, :bigint

    # Backfill existing comments
    safety_assured do
      execute <<-SQL.squish
        UPDATE comments
        SET commentable_type = 'ContentItem', commentable_id = content_item_id
        WHERE content_item_id IS NOT NULL
      SQL
    end

    # Add NOT NULL constraints after backfill
    safety_assured do
      change_column_null :comments, :commentable_type, false
      change_column_null :comments, :commentable_id, false
    end

    # Remove old indexes that reference content_item_id
    remove_index :comments, name: :index_comments_on_content_item_and_parent
    remove_index :comments, name: :index_comments_on_content_item_id

    # Add new polymorphic indexes
    add_index :comments, [ :commentable_type, :commentable_id ], name: :index_comments_on_commentable
    add_index :comments, [ :commentable_type, :commentable_id, :parent_id ], name: :index_comments_on_commentable_and_parent

    # Remove foreign key and column
    safety_assured do
      remove_foreign_key :comments, :content_items
      remove_column :comments, :content_item_id
    end
  end

  def down
    # Add back content_item_id column
    add_reference :comments, :content_item, foreign_key: true, null: true

    # Backfill from polymorphic columns (only ContentItem comments)
    safety_assured do
      execute <<-SQL.squish
        UPDATE comments
        SET content_item_id = commentable_id
        WHERE commentable_type = 'ContentItem'
      SQL

      # Delete comments that aren't for ContentItems (will be lost on rollback)
      execute <<-SQL.squish
        DELETE FROM comments
        WHERE commentable_type != 'ContentItem'
      SQL

      # Add NOT NULL constraint
      change_column_null :comments, :content_item_id, false
    end

    # Remove polymorphic indexes
    remove_index :comments, name: :index_comments_on_commentable
    remove_index :comments, name: :index_comments_on_commentable_and_parent

    # Add back old indexes
    add_index :comments, [ :content_item_id, :parent_id ], name: :index_comments_on_content_item_and_parent
    add_index :comments, :content_item_id, name: :index_comments_on_content_item_id

    # Remove polymorphic columns
    remove_column :comments, :commentable_type
    remove_column :comments, :commentable_id
  end
end
