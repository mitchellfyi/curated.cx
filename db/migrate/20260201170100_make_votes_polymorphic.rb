# frozen_string_literal: true

class MakeVotesPolymorphic < ActiveRecord::Migration[8.0]
  def up
    # Add polymorphic columns
    add_column :votes, :votable_type, :string
    add_column :votes, :votable_id, :bigint

    # Backfill existing votes (wrapped in safety_assured since execute is safe here)
    safety_assured do
      execute <<-SQL.squish
        UPDATE votes
        SET votable_type = 'ContentItem', votable_id = content_item_id
        WHERE content_item_id IS NOT NULL
      SQL
    end

    # Add NOT NULL constraints after backfill
    safety_assured do
      change_column_null :votes, :votable_type, false
      change_column_null :votes, :votable_id, false
    end

    # Remove old unique index
    remove_index :votes, name: :index_votes_uniqueness

    # Add new polymorphic unique index
    add_index :votes, [ :site_id, :user_id, :votable_type, :votable_id ],
              unique: true,
              name: :index_votes_uniqueness

    # Add index for polymorphic lookups
    add_index :votes, [ :votable_type, :votable_id ], name: :index_votes_on_votable

    # Remove foreign key and column
    safety_assured do
      remove_foreign_key :votes, :content_items
      remove_index :votes, :content_item_id
      remove_column :votes, :content_item_id
    end
  end

  def down
    # Add back content_item_id column
    add_reference :votes, :content_item, foreign_key: true, null: true

    # Backfill from polymorphic columns (only ContentItem votes)
    safety_assured do
      execute <<-SQL.squish
        UPDATE votes
        SET content_item_id = votable_id
        WHERE votable_type = 'ContentItem'
      SQL

      # Delete votes that aren't for ContentItems (will be lost on rollback)
      execute <<-SQL.squish
        DELETE FROM votes
        WHERE votable_type != 'ContentItem'
      SQL

      # Add NOT NULL constraint
      change_column_null :votes, :content_item_id, false
    end

    # Remove polymorphic indexes
    remove_index :votes, name: :index_votes_uniqueness
    remove_index :votes, name: :index_votes_on_votable

    # Add back old unique index
    add_index :votes, [ :site_id, :user_id, :content_item_id ],
              unique: true,
              name: :index_votes_uniqueness

    # Remove polymorphic columns
    remove_column :votes, :votable_type
    remove_column :votes, :votable_id
  end
end
