# frozen_string_literal: true

class CreateSequenceEmails < ActiveRecord::Migration[8.1]
  def change
    create_table :sequence_emails do |t|
      t.references :sequence_enrollment, null: false, foreign_key: true
      t.references :email_step, null: false, foreign_key: true
      t.integer :status, default: 0, null: false
      t.datetime :scheduled_for, null: false
      t.datetime :sent_at

      t.timestamps
    end

    add_index :sequence_emails, [ :status, :scheduled_for ]
  end
end
