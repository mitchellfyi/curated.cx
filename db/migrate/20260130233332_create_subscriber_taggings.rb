class CreateSubscriberTaggings < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriber_taggings do |t|
      t.references :digest_subscription, null: false, foreign_key: true
      t.references :subscriber_tag, null: false, foreign_key: true

      t.timestamps
    end

    add_index :subscriber_taggings, %i[digest_subscription_id subscriber_tag_id], unique: true, name: "index_subscriber_taggings_uniqueness"
  end
end
