# frozen_string_literal: true

class CreateBoostPayouts < ActiveRecord::Migration[8.0]
  def change
    create_table :boost_payouts do |t|
      t.references :site, null: false, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.date :period_start, null: false
      t.date :period_end, null: false
      t.integer :status, default: 0, null: false
      t.datetime :paid_at
      t.string :payment_reference
      t.timestamps

      t.index %i[site_id period_start]
      t.index :status
    end
  end
end
