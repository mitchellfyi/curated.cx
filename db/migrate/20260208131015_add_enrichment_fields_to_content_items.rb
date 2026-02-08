# frozen_string_literal: true

class AddEnrichmentFieldsToContentItems < ActiveRecord::Migration[8.0]
  def change
    add_column :content_items, :og_image_url, :string
    add_column :content_items, :word_count, :integer
    add_column :content_items, :read_time_minutes, :integer
    add_column :content_items, :author_name, :string
    add_column :content_items, :favicon_url, :string
  end
end
