class AddEditorialEnhancementFieldsToContentItems < ActiveRecord::Migration[8.1]
  def change
    add_column :content_items, :key_takeaways, :jsonb, default: []
    add_column :content_items, :audience_tags, :string, array: true, default: []
    add_column :content_items, :quality_score, :decimal, precision: 3, scale: 1
  end
end
