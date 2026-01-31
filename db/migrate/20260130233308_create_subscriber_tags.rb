class CreateSubscriberTags < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriber_tags do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.references :site, null: false, foreign_key: true
      t.references :tenant, null: false, foreign_key: true

      t.timestamps
    end

    add_index :subscriber_tags, %i[site_id slug], unique: true
  end
end
