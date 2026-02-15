# frozen_string_literal: true

class AddAffiliateFieldsToEntries < ActiveRecord::Migration[8.0]
  def change
    add_column :entries, :affiliate_eligible, :boolean, default: false, null: false
    add_column :entries, :affiliate_network, :string
    add_column :entries, :affiliate_url, :string

    add_index :entries, :affiliate_eligible, where: "affiliate_eligible = true"
    add_index :entries, :affiliate_network
  end
end
