# frozen_string_literal: true

class AddHiddenToComments < ActiveRecord::Migration[8.0]
  def change
    add_column :comments, :hidden_at, :datetime
    add_column :comments, :hidden_by_id, :bigint

    add_index :comments, :hidden_at
    add_foreign_key :comments, :users, column: :hidden_by_id
  end
end
