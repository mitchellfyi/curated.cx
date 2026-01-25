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
  },
  {
    slug: "dayz",
    hostname: "dayz.cx",
    title: "DayZ Community Hub",
    description: "Your source for DayZ news, mods, servers, and community content",
    settings: {
      theme: {
        primary_color: "green",
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

  # Ensure each tenant has a primary site
  site = Site.find_or_initialize_by(tenant: tenant, slug: tenant.slug)
  site.assign_attributes(
    name: tenant.title,
    description: tenant.description,
    config: tenant.settings,
    status: tenant.status
  )
  site.save!

  # Ensure primary domain exists and is verified
  primary_domain = site.domains.find_or_initialize_by(hostname: tenant.hostname)
  primary_domain.assign_attributes(primary: true, verified: true, status: :active, verified_at: Time.current)
  primary_domain.save!
  puts "    ↳ Site ready with domain #{primary_domain.hostname}"
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
  site = tenant.sites.find_by(slug: tenant.slug) || tenant.sites.first
  next unless site

  category_data.each do |attrs|
    next unless tenant.setting("categories.#{attrs[:key]}.enabled", false)

    category = Category.find_or_initialize_by(site: site, key: attrs[:key])
    category.assign_attributes(attrs.merge(tenant: tenant, site: site))
    category.save!
    puts "  ✓ Created/updated category for #{tenant.title}: #{category.name}"
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

# Seed listings for each tenant and category
puts "Seeding listings..."

# Define sample listings data by category and tenant
listings_data = {
  "root" => {
    "news" => [
      {
        url_raw: "https://techcrunch.com/2024/01/15/the-future-of-content-curation",
        title: "The Future of Content Curation: How AI is Changing Discovery",
        description: "Exploring how artificial intelligence is revolutionizing the way we discover and curate content across the web.",
        site_name: "TechCrunch",
        published_at: 3.days.ago
      },
      {
        url_raw: "https://wired.com/story/content-platforms-2024",
        title: "Content Platforms Are Getting Smarter",
        description: "A deep dive into how modern content platforms are using machine learning to improve user experience.",
        site_name: "WIRED",
        published_at: 5.days.ago
      },
      {
        url_raw: "https://medium.com/@tech/curation-trends",
        title: "Top 10 Content Curation Trends for 2024",
        description: "Industry experts share their predictions for the biggest trends in content curation this year.",
        site_name: "Medium",
        published_at: 1.week.ago
      }
    ]
  },
  "ai" => {
    "news" => [
      {
        url_raw: "https://openai.com/blog/gpt-4-turbo-preview",
        title: "Introducing GPT-4 Turbo Preview",
        description: "Our latest model with improved capabilities and reduced costs for developers worldwide.",
        site_name: "OpenAI",
        published_at: 2.days.ago
      },
      {
        url_raw: "https://anthropic.com/research/claude-3-opus",
        title: "Claude 3 Opus: New Frontiers in AI Reasoning",
        description: "Anthropic announces major breakthrough in large language model reasoning capabilities.",
        site_name: "Anthropic",
        published_at: 4.days.ago
      },
      {
        url_raw: "https://blog.google/technology/ai/gemini-advanced-update/",
        title: "Gemini Advanced Gets Major Updates",
        description: "Google's flagship AI model receives significant improvements in coding and mathematical reasoning.",
        site_name: "Google AI Blog",
        published_at: 6.days.ago
      }
    ],
    "apps" => [
      {
        url_raw: "https://github.com",
        title: "GitHub Copilot",
        description: "AI-powered code completion and programming assistant that helps developers write code faster.",
        site_name: "GitHub",
        published_at: nil
      },
      {
        url_raw: "https://claude.ai",
        title: "Claude",
        description: "Constitutional AI assistant for conversations, analysis, and creative tasks.",
        site_name: "Anthropic",
        published_at: nil
      },
      {
        url_raw: "https://midjourney.com",
        title: "Midjourney",
        description: "AI-powered image generation platform for creating stunning artwork and designs.",
        site_name: "Midjourney",
        published_at: nil
      }
    ],
    "services" => [
      {
        url_raw: "https://replicate.com",
        title: "Replicate API",
        description: "Run machine learning models in the cloud with simple API calls for image, text, and audio generation.",
        site_name: "Replicate",
        published_at: nil
      },
      {
        url_raw: "https://cloud.google.com",
        title: "Google Cloud AI Platform",
        description: "Machine learning platform for building, deploying, and scaling AI models.",
        site_name: "Google Cloud",
        published_at: nil
      },
      {
        url_raw: "https://aws.amazon.com",
        title: "Amazon Bedrock",
        description: "Fully managed service for building generative AI applications with foundation models.",
        site_name: "AWS",
        published_at: nil
      }
    ]
  },
  "construction" => {
    "news" => [
      {
        url_raw: "https://constructionnews.com/2024/01/bim-technology-advances",
        title: "BIM Technology Advances Reshape Construction Planning",
        description: "Latest developments in Building Information Modeling are transforming how construction projects are planned and executed.",
        site_name: "Construction News",
        published_at: 1.day.ago
      },
      {
        url_raw: "https://enr.com/articles/sustainable-construction-materials-2024",
        title: "Sustainable Construction Materials Gain Momentum in 2024",
        description: "Green building materials are becoming more accessible and cost-effective for major construction projects.",
        site_name: "Engineering News-Record",
        published_at: 3.days.ago
      },
      {
        url_raw: "https://constructiondive.com/news/robotics-automation-construction/",
        title: "Robotics and Automation Transform Construction Sites",
        description: "How robotic systems are improving safety and efficiency in modern construction projects.",
        site_name: "Construction Dive",
        published_at: 5.days.ago
      }
    ],
    "apps" => [
      {
        url_raw: "https://autodesk.com",
        title: "AutoCAD",
        description: "Industry-leading 2D and 3D CAD software for architectural and construction design.",
        site_name: "Autodesk",
        published_at: nil
      },
      {
        url_raw: "https://procore.com",
        title: "Procore",
        description: "Construction management software platform for project management, quality, and safety.",
        site_name: "Procore",
        published_at: nil
      },
      {
        url_raw: "https://planswift.com",
        title: "PlanSwift",
        description: "Digital takeoff and estimating software for construction professionals.",
        site_name: "PlanSwift",
        published_at: nil
      }
    ],
    "services" => [
      {
        url_raw: "https://buildertrend.com",
        title: "Buildertrend",
        description: "Cloud-based project management and customer management platform for construction professionals.",
        site_name: "Buildertrend",
        published_at: nil
      },
      {
        url_raw: "https://constructionline.com",
        title: "Constructionline",
        description: "UK's largest register of construction contractors, consultants and material suppliers.",
        site_name: "Constructionline",
        published_at: nil
      },
      {
        url_raw: "https://dodge.com",
        title: "Dodge Data & Analytics",
        description: "Construction project leads, market analytics, and business intelligence for the industry.",
        site_name: "Dodge",
        published_at: nil
      }
    ]
  },
  "dayz" => {
    "news" => [
      {
        url_raw: "https://dayz.com/article/devblog/status-report-january-2024",
        title: "DayZ Status Report: January 2024 Update",
        description: "Bohemia Interactive shares the latest development progress, upcoming features, and community highlights for DayZ.",
        site_name: "DayZ Official",
        published_at: 2.days.ago
      },
      {
        url_raw: "https://www.reddit.com/r/dayz/comments/new-experimental-patch",
        title: "Experimental 1.24 Patch Brings Major Base Building Changes",
        description: "The latest experimental patch introduces significant improvements to base building mechanics and new construction options.",
        site_name: "Reddit r/dayz",
        published_at: 4.days.ago
      },
      {
        url_raw: "https://store.steampowered.com/news/app/221100",
        title: "DayZ Frostline DLC Announced for 2024",
        description: "Bohemia Interactive announces new premium DLC featuring a frozen northern map with unique survival challenges.",
        site_name: "Steam News",
        published_at: 1.week.ago
      }
    ],
    "apps" => [
      {
        url_raw: "https://dayzsalauncher.com",
        title: "DayZSA Launcher",
        description: "Popular community launcher for DayZ with mod management, server browser, and automatic mod downloads.",
        site_name: "DayZSA Launcher",
        published_at: nil
      },
      {
        url_raw: "https://www.izurvive.com",
        title: "iZurvive Map",
        description: "Interactive map for DayZ and ARMA with loot spawns, vehicle locations, and community markers.",
        site_name: "iZurvive",
        published_at: nil
      },
      {
        url_raw: "https://github.com/CFTools/cftools-sdk",
        title: "CFTools Cloud",
        description: "Server management platform for DayZ with player stats, ban lists, and real-time monitoring.",
        site_name: "CFTools",
        published_at: nil
      }
    ],
    "services" => [
      {
        url_raw: "https://nitrado.net/dayz",
        title: "Nitrado DayZ Servers",
        description: "Official DayZ server hosting partner with instant deployment, mod support, and global locations.",
        site_name: "Nitrado",
        published_at: nil
      },
      {
        url_raw: "https://www.gameservers.com/game_servers/dayz.php",
        title: "GameServers.com DayZ Hosting",
        description: "Premium DayZ server hosting with DDoS protection, instant setup, and 24/7 support.",
        site_name: "GameServers",
        published_at: nil
      },
      {
        url_raw: "https://dayzunderground.com",
        title: "DayZ Underground",
        description: "Popular roleplay-focused DayZ community server with unique factions and immersive gameplay.",
        site_name: "DayZ Underground",
        published_at: nil
      }
    ]
  }
}

# Create listings for each tenant
Tenant.all.each do |tenant|
  next unless listings_data[tenant.slug]

  site = tenant.sites.find_by(slug: tenant.slug) || tenant.sites.first
  next unless site

  tenant_listing_data = listings_data[tenant.slug]

  tenant_listing_data.each do |category_key, listings|
    category = Category.find_by(site: site, key: category_key)
    next unless category

    listings.each do |listing_attrs|
      canonical_url = UrlCanonicaliser.canonicalize(listing_attrs[:url_raw]) rescue listing_attrs[:url_raw]

      listing = Listing.find_or_initialize_by(site: site, url_canonical: canonical_url)
      listing.assign_attributes(
        tenant: tenant,
        category: category,
        site: site,
        url_raw: listing_attrs[:url_raw],
        url_canonical: canonical_url,
        title: listing_attrs[:title],
        description: listing_attrs[:description],
        site_name: listing_attrs[:site_name],
        published_at: listing_attrs[:published_at]
      )
      listing.save!
      puts "  ✓ Created/updated listing for #{tenant.title}/#{category.name}: #{listing.title}"
    end
  end
end

puts "Listing seeding complete!"

# Display summary
puts "\n=== Seeding Summary ==="
Tenant.all.each do |tenant|
  site = tenant.sites.find_by(slug: tenant.slug) || tenant.sites.first
  next unless site

  Current.site = site

  total_listings = Listing.count
  categories_with_counts = Category.includes(:listings).map { |cat| "#{cat.name}: #{cat.listings.count}" }.join(", ")
  puts "#{tenant.title}: #{total_listings} total listings (#{categories_with_counts})"
end
Current.site = nil
puts "GRAND TOTAL: #{Listing.count} listings across all tenants"
puts "TARGET ACHIEVED: Exactly 3 listings per category per tenant ✅"
puts "========================"
