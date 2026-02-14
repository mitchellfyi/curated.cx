# frozen_string_literal: true

class AddNetworkAndConversionToAffiliateClicks < ActiveRecord::Migration[8.0]
  def change
    add_column :affiliate_clicks, :network, :string
    add_column :affiliate_clicks, :converted, :boolean, default: false, null: false
    add_column :affiliate_clicks, :commission_cents, :decimal, precision: 10, scale: 2
    add_reference :affiliate_clicks, :user, null: true, foreign_key: true

    add_index :affiliate_clicks, :network
    add_index :affiliate_clicks, :converted
  end
end
