# frozen_string_literal: true

class AddModerationFieldsToContentItems < ActiveRecord::Migration[8.0]
  def change
    # Hide content
    add_column :content_items, :hidden_at, :datetime
    add_reference :content_items, :hidden_by, foreign_key: { to_table: :users }

    # Lock comments
    add_column :content_items, :comments_locked_at, :datetime
    add_reference :content_items, :comments_locked_by, foreign_key: { to_table: :users }

    # Index for filtering hidden content in queries
    add_index :content_items, :hidden_at, name: "index_content_items_on_hidden_at"
  end
end
