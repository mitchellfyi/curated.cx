# frozen_string_literal: true

class AddTaggingFieldsToContentItems < ActiveRecord::Migration[8.0]
  def change
    add_column :content_items, :topic_tags, :jsonb, null: false, default: []
    add_column :content_items, :content_type, :string
    add_column :content_items, :tagging_confidence, :decimal, precision: 3, scale: 2
    add_column :content_items, :tagging_explanation, :jsonb, null: false, default: []

    add_index :content_items, %i[site_id content_type]
  end
end
