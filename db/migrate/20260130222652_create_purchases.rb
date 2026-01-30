# frozen_string_literal: true

class CreatePurchases < ActiveRecord::Migration[8.1]
  def change
    create_table :purchases do |t|
      t.references :site, null: false, foreign_key: true
      t.references :digital_product, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.string :email, null: false
      t.integer :amount_cents, null: false, default: 0
      t.string :stripe_payment_intent_id
      t.string :stripe_checkout_session_id
      t.datetime :purchased_at, null: false
      t.integer :source, null: false, default: 0

      t.timestamps
    end

    add_index :purchases, :stripe_checkout_session_id, unique: true, where: "stripe_checkout_session_id IS NOT NULL"
    add_index :purchases, :stripe_payment_intent_id, unique: true, where: "stripe_payment_intent_id IS NOT NULL"
    add_index :purchases, %i[site_id digital_product_id email]
    add_index :purchases, %i[site_id purchased_at]
  end
end
