# frozen_string_literal: true

class AddScreenshotFieldsToContentItems < ActiveRecord::Migration[8.0]
  def change
    add_column :content_items, :screenshot_url, :string
    add_column :content_items, :screenshot_captured_at, :datetime
  end
end
