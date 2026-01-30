# frozen_string_literal: true

class AddScheduledForToListings < ActiveRecord::Migration[8.0]
  def change
    add_column :listings, :scheduled_for, :datetime

    # Partial index on non-null values for efficient job queries
    add_index :listings, :scheduled_for, where: "scheduled_for IS NOT NULL"
  end
end
