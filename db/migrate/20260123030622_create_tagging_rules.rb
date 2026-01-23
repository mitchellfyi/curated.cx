# frozen_string_literal: true

class CreateTaggingRules < ActiveRecord::Migration[8.0]
  def change
    create_table :tagging_rules do |t|
      t.references :site, null: false, foreign_key: true
      t.references :tenant, null: false, foreign_key: true
      t.references :taxonomy, null: false, foreign_key: true
      t.integer :rule_type, null: false
      t.text :pattern, null: false
      t.integer :priority, null: false, default: 100
      t.boolean :enabled, null: false, default: true

      t.timestamps
    end

    add_index :tagging_rules, %i[site_id priority]
    add_index :tagging_rules, %i[site_id enabled]
  end
end
