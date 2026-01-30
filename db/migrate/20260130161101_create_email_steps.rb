# frozen_string_literal: true

class CreateEmailSteps < ActiveRecord::Migration[8.1]
  def change
    create_table :email_steps do |t|
      t.references :email_sequence, null: false, foreign_key: true
      t.integer :position, default: 0, null: false
      t.integer :delay_seconds, default: 0, null: false
      t.string :subject, null: false
      t.text :body_html, null: false
      t.text :body_text

      t.timestamps
    end

    add_index :email_steps, [ :email_sequence_id, :position ], unique: true
  end
end
