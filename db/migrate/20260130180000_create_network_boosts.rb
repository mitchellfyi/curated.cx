# frozen_string_literal: true

class CreateNetworkBoosts < ActiveRecord::Migration[8.0]
  def change
    create_table :network_boosts do |t|
      t.references :source_site, null: false, foreign_key: { to_table: :sites }
      t.references :target_site, null: false, foreign_key: { to_table: :sites }
      t.decimal :cpc_rate, precision: 8, scale: 2, null: false
      t.decimal :monthly_budget, precision: 10, scale: 2
      t.decimal :spent_this_month, precision: 10, scale: 2, default: 0
      t.boolean :enabled, default: true, null: false
      t.timestamps

      t.index %i[source_site_id target_site_id], unique: true
      t.index %i[target_site_id enabled]
    end
  end
end
