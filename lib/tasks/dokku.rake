# frozen_string_literal: true

namespace :dokku do
  desc "Output all active domains as JSON for Dokku sync"
  task domains: :environment do
    domains = Domain.where(status: :active).pluck(:hostname)
    tenant_hostnames = Tenant.where(status: :enabled).pluck(:hostname)

    # Combine and deduplicate
    all_domains = (domains + tenant_hostnames).uniq.sort

    puts all_domains.to_json
  end

  desc "Output domain sync status"
  task domain_status: :environment do
    puts "=== Active Domains ==="
    Domain.where(status: :active).includes(:site).find_each do |domain|
      puts "  #{domain.hostname} (Site: #{domain.site&.name || 'N/A'}, Primary: #{domain.primary?})"
    end

    puts "\n=== Tenant Hostnames ==="
    Tenant.where(status: :enabled).find_each do |tenant|
      puts "  #{tenant.hostname} (#{tenant.title})"
    end
  end
end
