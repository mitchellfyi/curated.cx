# frozen_string_literal: true

class CreateEmailSequences < ActiveRecord::Migration[8.1]
  def change
    create_table :email_sequences do |t|
      t.references :site, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :trigger_type, default: 0, null: false
      t.jsonb :trigger_config, default: {}
      t.boolean :enabled, default: false, null: false

      t.timestamps
    end

    add_index :email_sequences, [ :site_id, :trigger_type, :enabled ]
  end
end
