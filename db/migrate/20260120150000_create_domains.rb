# frozen_string_literal: true

class CreateDomains < ActiveRecord::Migration[8.0]
  def change
    create_table :domains do |t|
      t.references :site, null: false, foreign_key: true
      t.string :hostname, null: false
      t.boolean :verified, default: false, null: false
      t.datetime :verified_at
      t.boolean :primary, default: false, null: false
      t.integer :status, default: 0, null: false # enum: pending_dns(0), verified_dns(1), ssl_pending(2), active(3), failed(4)
      t.datetime :last_checked_at
      t.text :last_error

      t.timestamps
    end

    add_index :domains, :hostname, unique: true
    add_index :domains, [ :site_id, :verified ]
    add_index :domains, :status
    # Partial unique index: only one primary domain per site
    add_index :domains, :site_id, unique: true, where: '"primary" = true', name: "index_domains_on_site_id_where_primary"
  end
end
