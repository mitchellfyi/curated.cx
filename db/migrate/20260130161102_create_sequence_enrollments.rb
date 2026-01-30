# frozen_string_literal: true

class CreateSequenceEnrollments < ActiveRecord::Migration[8.1]
  def change
    create_table :sequence_enrollments do |t|
      t.references :email_sequence, null: false, foreign_key: true
      t.references :digest_subscription, null: false, foreign_key: true
      t.integer :status, default: 0, null: false
      t.integer :current_step_position, default: 0, null: false
      t.datetime :enrolled_at, null: false
      t.datetime :completed_at

      t.timestamps
    end

    add_index :sequence_enrollments, [ :email_sequence_id, :digest_subscription_id ], unique: true, name: "idx_enrollments_sequence_subscription"
    add_index :sequence_enrollments, :status
  end
end
