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

# Seed categories for each tenant
puts "Seeding categories..."

category_data = [
  {
    key: "news",
    name: "News",
    allow_paths: true,
    shown_fields: {
      title: true,
      description: true,
      image_url: true,
      site_name: true,
      published_at: true,
      ai_summary: false
    }
  },
  {
    key: "apps",
    name: "Apps & Tools", 
    allow_paths: false,
    shown_fields: {
      title: true,
      description: true,
      image_url: true,
      site_name: true,
      ai_summary: true
    }
  },
  {
    key: "services",
    name: "Services",
    allow_paths: false,
    shown_fields: {
      title: true,
      description: true,
      image_url: true,
      site_name: true,
      ai_summary: true
    }
  }
]

Tenant.all.each do |tenant|
  ActsAsTenant.with_tenant(tenant) do
    category_data.each do |attrs|
      # Only create categories enabled in tenant settings
      if tenant.setting("categories.#{attrs[:key]}.enabled", false)
        category = Category.find_or_initialize_by(key: attrs[:key])
        category.assign_attributes(attrs)
        category.save!
        puts "  ✓ Created/updated category for #{tenant.title}: #{category.name}"
      end
    end
  end
end

puts "Category seeding complete!"

# Seed users and roles
puts "Seeding users and roles..."

# Create developer user with admin access
developer_email = Rails.application.credentials.dig(:developer, :email) || "developer@curated.cx"
developer_password = Rails.application.credentials.dig(:developer, :password) || "password123"

developer = User.find_or_initialize_by(email: developer_email)
developer.assign_attributes(
  email: developer_email,
  password: developer_password,
  password_confirmation: developer_password,
  admin: true
)
developer.save!
puts "  ✓ Created/updated developer user: #{developer.email}"

# Create tenant owners
tenants = Tenant.all

tenants.each do |tenant|
  owner_email = "owner@#{tenant.hostname}"
  owner_password = "password123"

  owner = User.find_or_initialize_by(email: owner_email)
  owner.assign_attributes(
    email: owner_email,
    password: owner_password,
    password_confirmation: owner_password,
    admin: false
  )
  owner.save!

  # Assign owner role to tenant
  owner.add_role(:owner, tenant) unless owner.has_role?(:owner, tenant)
  puts "  ✓ Created/updated owner for #{tenant.title}: #{owner.email}"
end

puts "User and role seeding complete!"
