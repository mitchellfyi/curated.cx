# frozen_string_literal: true

class AddEditorialisationFieldsToContentItems < ActiveRecord::Migration[8.0]
  def change
    add_column :content_items, :ai_summary, :text
    add_column :content_items, :why_it_matters, :text
    add_column :content_items, :ai_suggested_tags, :jsonb, default: [], null: false
    add_column :content_items, :editorialised_at, :datetime

    add_index :content_items, [ :site_id, :editorialised_at ]
  end
end
