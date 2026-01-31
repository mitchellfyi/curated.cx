class CreateSubscriberSegments < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriber_segments do |t|
      t.string :name, null: false
      t.text :description
      t.jsonb :rules, null: false, default: {}
      t.boolean :system_segment, null: false, default: false
      t.boolean :enabled, null: false, default: true
      t.references :site, null: false, foreign_key: true
      t.references :tenant, null: false, foreign_key: true

      t.timestamps
    end

    add_index :subscriber_segments, %i[site_id enabled]
    add_index :subscriber_segments, %i[site_id system_segment]
  end
end
