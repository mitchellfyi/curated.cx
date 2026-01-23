# frozen_string_literal: true

class AddMonetisationFieldsToListings < ActiveRecord::Migration[8.0]
  def change
    # Listing type (tool, job, service)
    add_column :listings, :listing_type, :integer, default: 0, null: false

    # Affiliate fields
    add_column :listings, :affiliate_url_template, :text
    add_column :listings, :affiliate_attribution, :jsonb, default: {}, null: false

    # Featured placement fields
    add_column :listings, :featured_from, :datetime
    add_column :listings, :featured_until, :datetime
    add_reference :listings, :featured_by, foreign_key: { to_table: :users }

    # Job board fields
    add_column :listings, :company, :string
    add_column :listings, :location, :string
    add_column :listings, :salary_range, :string
    add_column :listings, :apply_url, :text
    add_column :listings, :expires_at, :datetime

    # Payment fields (stub for future Stripe integration)
    add_column :listings, :paid, :boolean, default: false, null: false
    add_column :listings, :payment_reference, :string

    # Indexes for monetisation queries
    add_index :listings, %i[site_id featured_from featured_until],
              name: "index_listings_on_site_featured_dates"
    add_index :listings, %i[site_id expires_at],
              name: "index_listings_on_site_expires_at"
    add_index :listings, %i[site_id listing_type],
              name: "index_listings_on_site_listing_type"
    add_index :listings, %i[site_id listing_type expires_at],
              name: "index_listings_on_site_type_expires"
  end
end
