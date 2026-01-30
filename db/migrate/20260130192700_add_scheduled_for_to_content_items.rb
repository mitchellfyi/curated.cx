# frozen_string_literal: true

class AddScheduledForToContentItems < ActiveRecord::Migration[8.0]
  def change
    add_column :content_items, :scheduled_for, :datetime

    # Partial index on non-null values for efficient job queries
    add_index :content_items, :scheduled_for, where: "scheduled_for IS NOT NULL"
  end
end
