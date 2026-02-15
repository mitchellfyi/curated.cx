# frozen_string_literal: true

class CreateBusinessClaims < ActiveRecord::Migration[8.0]
  def change
    create_table :business_claims do |t|
      t.references :entry, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :status, default: "pending", null: false
      t.string :verification_method
      t.string :verification_code
      t.datetime :verified_at

      t.timestamps
    end

    add_index :business_claims, :status
    add_index :business_claims, [ :entry_id, :user_id ], unique: true
  end
end
