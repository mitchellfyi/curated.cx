# frozen_string_literal: true

class ChangeSponsorshipMonetaryFieldsToBigint < ActiveRecord::Migration[8.0]
  def up
    change_column :sponsorships, :budget_cents, :bigint, default: 0, null: false
    change_column :sponsorships, :spent_cents, :bigint, default: 0, null: false
  end

  def down
    change_column :sponsorships, :budget_cents, :integer, default: 0, null: false
    change_column :sponsorships, :spent_cents, :integer, default: 0, null: false
  end
end
