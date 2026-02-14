# frozen_string_literal: true

class CreateBusinessSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :business_subscriptions do |t|
      t.references :entry, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :tier, null: false
      t.string :stripe_subscription_id
      t.datetime :current_period_start
      t.datetime :current_period_end
      t.string :status, default: "active", null: false

      t.timestamps
    end

    add_index :business_subscriptions, :tier
    add_index :business_subscriptions, :status
    add_index :business_subscriptions, :stripe_subscription_id, unique: true, where: "stripe_subscription_id IS NOT NULL"
    add_index :business_subscriptions, [:entry_id, :status]
  end
end
