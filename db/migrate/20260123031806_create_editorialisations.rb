# frozen_string_literal: true

class CreateEditorialisations < ActiveRecord::Migration[8.0]
  def change
    create_table :editorialisations do |t|
      t.references :site, null: false, foreign_key: true
      t.references :content_item, null: false, foreign_key: true
      t.string :prompt_version, null: false
      t.text :prompt_text, null: false
      t.text :raw_response
      t.jsonb :parsed_response, default: {}, null: false
      t.integer :status, default: 0, null: false
      t.text :error_message
      t.integer :tokens_used
      t.string :model_name
      t.integer :duration_ms

      t.timestamps
    end

    add_index :editorialisations, :content_item_id, unique: true
    add_index :editorialisations, [ :site_id, :status ]
    add_index :editorialisations, [ :site_id, :created_at ]
  end
end
