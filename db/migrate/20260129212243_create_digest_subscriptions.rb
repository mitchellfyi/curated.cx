# frozen_string_literal: true

class CreateDigestSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :digest_subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :site, null: false, foreign_key: true
      t.integer :frequency, null: false, default: 0 # weekly
      t.boolean :active, null: false, default: true
      t.datetime :last_sent_at
      t.string :unsubscribe_token, null: false
      t.jsonb :preferences, null: false, default: {}

      t.timestamps
    end

    add_index :digest_subscriptions, [ :user_id, :site_id ], unique: true
    add_index :digest_subscriptions, :unsubscribe_token, unique: true
    add_index :digest_subscriptions, [ :site_id, :frequency, :active ]
  end
end
