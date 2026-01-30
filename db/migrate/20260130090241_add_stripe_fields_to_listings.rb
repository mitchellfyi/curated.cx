# frozen_string_literal: true

class AddStripeFieldsToListings < ActiveRecord::Migration[8.1]
  def change
    add_column :listings, :stripe_checkout_session_id, :string
    add_column :listings, :stripe_payment_intent_id, :string
    add_column :listings, :payment_status, :integer, default: 0, null: false

    add_index :listings, :stripe_checkout_session_id, unique: true, where: "stripe_checkout_session_id IS NOT NULL"
    add_index :listings, :stripe_payment_intent_id, unique: true, where: "stripe_payment_intent_id IS NOT NULL"
    add_index :listings, :payment_status
  end
end
