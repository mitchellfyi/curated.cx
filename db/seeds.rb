# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Seed tenants for multi-tenancy
puts "Seeding tenants..."

tenant_data = [
  {
    slug: "root",
    hostname: "curated.cx",
    title: "Curated.cx",
    description: "The central hub for curated industry content",
    settings: {
      theme: {
        primary_color: "blue",
        secondary_color: "gray"
      },
      categories: {
        news: { enabled: true },
        apps: { enabled: false },
        services: { enabled: false }
      }
    },
    status: "enabled"
  },
  {
    slug: "ai",
    hostname: "ainews.cx",
    title: "AI News",
    description: "Curated AI industry news and insights",
    settings: {
      theme: {
        primary_color: "purple",
        secondary_color: "gray"
      },
      categories: {
        news: { enabled: true },
        apps: { enabled: true },
        services: { enabled: true }
      }
    },
    status: "enabled"
  },
  {
    slug: "construction",
    hostname: "construction.cx",
    title: "Construction News",
    description: "Latest construction industry news and trends",
    settings: {
      theme: {
        primary_color: "amber",
        secondary_color: "gray"
      },
      categories: {
        news: { enabled: true },
        apps: { enabled: true },
        services: { enabled: true }
      }
    },
    status: "enabled"
  }
]

tenant_data.each do |attrs|
  tenant = Tenant.find_or_initialize_by(slug: attrs[:slug])
  tenant.assign_attributes(attrs)
  tenant.save!
  puts "  ✓ Created/updated tenant: #{tenant.title} (#{tenant.hostname})"
end

puts "Tenant seeding complete!"
