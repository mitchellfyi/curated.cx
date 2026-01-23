# frozen_string_literal: true

namespace :tenants do
  desc "Ensure all tenants have default sites with domains"
  task ensure_default_sites: :environment do
    puts "Checking tenants for missing sites..."

    tenants_without_sites = Tenant.left_joins(:sites).where(sites: { id: nil })
    count = tenants_without_sites.count

    if count.zero?
      puts "All tenants have sites. Nothing to do."
      next
    end

    puts "Found #{count} tenant(s) without sites."

    tenants_without_sites.find_each do |tenant|
      create_default_site_for_tenant(tenant)
    end

    puts "Done. Created sites for #{count} tenant(s)."
  end

  desc "List tenants without sites"
  task list_without_sites: :environment do
    tenants_without_sites = Tenant.left_joins(:sites).where(sites: { id: nil })

    if tenants_without_sites.none?
      puts "All tenants have sites."
    else
      puts "Tenants without sites:"
      tenants_without_sites.find_each do |tenant|
        puts "  - #{tenant.slug} (#{tenant.hostname})"
      end
    end
  end

  private

  def create_default_site_for_tenant(tenant)
    ActiveRecord::Base.transaction do
      # Use advisory lock to prevent race conditions
      lock_key = "tenant_site_creation_#{tenant.id}".hash.abs % (2**31)

      ActiveRecord::Base.connection.execute(
        "SELECT pg_advisory_xact_lock(#{lock_key})"
      )

      # Double-check after acquiring lock
      existing_site = Site.find_by(tenant: tenant, slug: tenant.slug)
      if existing_site
        puts "  Skipping #{tenant.slug} - site already exists (race condition avoided)"
        return existing_site
      end

      site = Site.create!(
        tenant: tenant,
        slug: tenant.slug,
        name: tenant.title,
        description: tenant.description,
        status: tenant.status,
        config: tenant.settings
      )

      site.domains.create!(
        hostname: tenant.hostname,
        primary: true,
        verified: true
      )

      puts "  Created site for #{tenant.slug} (#{tenant.hostname})"
      site
    end
  rescue ActiveRecord::RecordInvalid => e
    puts "  Error creating site for #{tenant.slug}: #{e.message}"
    nil
  end
end
