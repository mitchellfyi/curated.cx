class AddEnrichmentPipelineFieldsToContentItems < ActiveRecord::Migration[8.1]
  def change
    add_column :content_items, :enrichment_status, :string, default: "pending", null: false
    add_column :content_items, :enriched_at, :datetime
    add_column :content_items, :enrichment_errors, :jsonb, default: [], null: false

    add_index :content_items, :enrichment_status
  end
end
