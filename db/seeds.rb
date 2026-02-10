# frozen_string_literal: true

# Seeds are IDEMPOTENT: safe to run multiple times (e.g. bin/rails db:seed).
# All records use find_or_initialize_by / find_or_initialize_by with stable unique keys,
# then assign_attributes and save!, so re-running updates existing rows instead of creating duplicates.

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
        apps: { enabled: true },
        services: { enabled: true }
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
# Categories define directory entry sections (tools, jobs, services, etc.)
# They are NOT used for feed entries - those use Taxonomies (topic tags).
puts "Seeding categories..."

category_data = [
  {
    key: "news",
    name: "News",
    category_type: "article",
    display_template: "list",
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
    category_type: "product",
    display_template: "grid",
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
    category_type: "service",
    display_template: "grid",
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
    # Root tenant gets all categories; others check settings
    enabled = tenant.slug == "root" || tenant.setting("categories.#{attrs[:key]}.enabled", false)
    next unless enabled

    category = Category.find_or_initialize_by(site: site, key: attrs[:key])
    category.assign_attributes(attrs.merge(tenant: tenant, site: site))
    category.save!
    puts "  ✓ Created/updated category for #{tenant.title}: #{category.name}"
  end
end

puts "Category seeding complete!"

# Seed users and roles
puts "Seeding users and roles..."

# Create developer user with admin access from Rails credentials
developer_email = Rails.application.credentials.dig(:developer, :email)
developer_password = Rails.application.credentials.dig(:developer, :password)

if developer_email.blank? || developer_password.blank?
  puts "  ⚠ Skipping developer user: credentials.developer.email/password not set"
  puts "    Run: rails credentials:edit and add:"
  puts "      developer:"
  puts "        email: your@email.com"
  puts "        password: your_secure_password"
else
  developer = User.find_or_initialize_by(email: developer_email)
  developer.assign_attributes(
    email: developer_email,
    password: developer_password,
    password_confirmation: developer_password,
    admin: true
  )
  developer.save!
  puts "  ✓ Created/updated developer admin: #{developer.email}"
end

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

# Seed directory entries for each tenant and category
puts "Seeding directory entries..."

# Define sample entries data by category and tenant
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
        url_raw: "https://cftools.cloud",
        title: "CFTools Cloud",
        description: "Server management platform for DayZ with player stats, ban lists, and real-time monitoring.",
        site_name: "CFTools",
        published_at: nil
      }
    ],
    "services" => [
      {
        url_raw: "https://nitrado.net",
        title: "Nitrado DayZ Servers",
        description: "Official DayZ server hosting partner with instant deployment, mod support, and global locations.",
        site_name: "Nitrado",
        published_at: nil
      },
      {
        url_raw: "https://gameservers.com",
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

# Create directory entries for each tenant
Tenant.all.each do |tenant|
  next unless listings_data[tenant.slug]

  site = tenant.sites.find_by(slug: tenant.slug) || tenant.sites.first
  next unless site

  tenant_listing_data = listings_data[tenant.slug]

  tenant_listing_data.each do |category_key, listings|
    category = Category.find_by(site: site, key: category_key)
    next unless category

    listing_type = (category_key == "services" ? 2 : 0) # 0=tool, 2=service

    listings.each do |listing_attrs|
      canonical_url = UrlCanonicaliser.canonicalize(listing_attrs[:url_raw]) rescue listing_attrs[:url_raw]

      entry = Entry.find_or_initialize_by(site: site, url_canonical: canonical_url, entry_kind: "directory")
      entry.assign_attributes(
        tenant: tenant,
        category: category,
        site: site,
        entry_kind: "directory",
        listing_type: listing_type,
        url_raw: listing_attrs[:url_raw],
        url_canonical: canonical_url,
        title: listing_attrs[:title],
        description: listing_attrs[:description],
        site_name: listing_attrs[:site_name],
        published_at: listing_attrs[:published_at]
      )
      entry.save!
      puts "  ✓ Created/updated entry for #{tenant.title}/#{category.name}: #{entry.title}"
    end
  end
end

puts "Directory entry seeding complete!"

# Display summary (scoped per tenant for correct counts)
puts "\n=== Seeding Summary ==="
grand_total_entries = 0
Tenant.all.each do |tenant|
  site = tenant.sites.find_by(slug: tenant.slug) || tenant.sites.first
  next unless site

  Current.site = site
  Current.tenant = tenant

  site_categories = Category.where(site: site)
  total_entries = Entry.directory_items.where(site: site).count
  grand_total_entries += total_entries
  categories_with_counts = site_categories.map { |cat| "#{cat.name}: #{Entry.directory_items.where(site: site, category: cat).count}" }.join(", ")
  puts "#{tenant.title}: #{total_entries} total directory entries (#{categories_with_counts})"
end
Current.site = nil
Current.tenant = nil
puts "GRAND TOTAL: #{grand_total_entries} directory entries across all tenants"
puts "========================"

# =============================================
# CONTENT SOURCES SEEDING
# =============================================

puts "\n=== Seeding Content Sources ==="

# Source configuration per tenant
source_configs = {
  "ai" => [
    {
      name: "AI News - General",
      kind: :serp_api_google_news,
      config: {
        query: "artificial intelligence news OR machine learning news",
        location: "United States",
        language: "en",
        max_results: 50,
        editorialise: true
      },
      schedule: { interval_seconds: 3600 }  # 1 hour
    },
    {
      name: "AI Tools & Products",
      kind: :serp_api_google_news,
      config: {
        query: "AI tools OR AI apps OR ChatGPT OR Claude AI OR Gemini AI",
        location: "United States",
        language: "en",
        max_results: 30,
        editorialise: true
      },
      schedule: { interval_seconds: 7200 }  # 2 hours
    }
  ],
  "construction" => [
    {
      name: "Construction Industry News",
      kind: :serp_api_google_news,
      config: {
        query: "construction industry news OR building materials",
        location: "United States",
        language: "en",
        max_results: 50,
        editorialise: true
      },
      schedule: { interval_seconds: 3600 }
    },
    {
      name: "Construction Technology",
      kind: :serp_api_google_news,
      config: {
        query: "construction technology OR ConTech OR building automation",
        location: "United States",
        language: "en",
        max_results: 30,
        editorialise: true
      },
      schedule: { interval_seconds: 7200 }
    }
  ],
  "dayz" => [
    {
      name: "DayZ Game News",
      kind: :serp_api_google_news,
      config: {
        query: "DayZ game news OR DayZ update OR DayZ patch",
        location: "United States",
        language: "en",
        max_results: 30,
        editorialise: true
      },
      schedule: { interval_seconds: 3600 }
    },
    {
      name: "DayZ Community",
      kind: :serp_api_google_news,
      config: {
        query: "DayZ mods OR DayZ servers OR DayZ community",
        location: "United States",
        language: "en",
        max_results: 20,
        editorialise: true
      },
      schedule: { interval_seconds: 7200 }
    }
  ]
}

source_configs.each do |tenant_slug, sources|
  tenant = Tenant.find_by(slug: tenant_slug)
  next unless tenant

  site = tenant.sites.find_by(slug: tenant_slug) || tenant.sites.first
  next unless site

  sources.each do |source_attrs|
    source = Source.find_or_initialize_by(site: site, name: source_attrs[:name])
    source.assign_attributes(
      tenant: tenant,
      kind: source_attrs[:kind],
      enabled: true,
      config: source_attrs[:config],
      schedule: source_attrs[:schedule],
      quality_weight: 1.0
    )
    source.save!
    puts "  ✓ Created/updated source for #{tenant.title}: #{source.name}"
  end
end

puts "Source seeding complete!"
puts "Total sources: #{Source.count}"

# =============================================
# EXTENDED CATEGORIES SEEDING
# =============================================

puts "\n=== Seeding Extended Categories ==="

# Standard categories for all tenants (with proper category_type)
standard_categories = [
  { key: "jobs", name: "Jobs", category_type: "job", display_template: "list",
    allow_paths: true,
    shown_fields: { company: true, location: true, salary_range: true, apply_url: true } },
  { key: "events", name: "Events", category_type: "event", display_template: "calendar",
    allow_paths: true,
    shown_fields: { location: true, description: true } }
]

# Tenant-specific categories (with proper category_type)
tenant_specific_categories = {
  "ai" => [
    { key: "models", name: "AI Models", category_type: "product", display_template: "grid",
      shown_fields: { description: true, company: true } },
    { key: "datasets", name: "Datasets", category_type: "resource", display_template: "grid",
      shown_fields: { description: true } },
    { key: "research", name: "Research Papers", category_type: "resource", display_template: "list",
      shown_fields: { description: true } }
  ],
  "construction" => [
    { key: "suppliers", name: "Material Suppliers", category_type: "service", display_template: "grid",
      shown_fields: { company: true, location: true } },
    { key: "contractors", name: "Contractors", category_type: "service", display_template: "grid",
      shown_fields: { company: true, location: true } },
    { key: "equipment", name: "Equipment", category_type: "product", display_template: "grid",
      shown_fields: { company: true, description: true } }
  ],
  "dayz" => [
    { key: "servers", name: "Game Servers", category_type: "service", display_template: "grid",
      shown_fields: { description: true, location: true } },
    { key: "mods", name: "Mods & Add-ons", category_type: "product", display_template: "grid",
      shown_fields: { description: true } },
    { key: "guides", name: "Guides & Tutorials", category_type: "resource", display_template: "list",
      shown_fields: { description: true } }
  ]
}

Tenant.all.each do |tenant|
  site = tenant.sites.find_by(slug: tenant.slug) || tenant.sites.first
  next unless site

  # Create standard categories
  standard_categories.each do |cat_attrs|
    category = Category.find_or_initialize_by(site: site, key: cat_attrs[:key])
    category.assign_attributes(cat_attrs.merge(tenant: tenant))
    category.save!
  end

  # Create tenant-specific categories
  specific_cats = tenant_specific_categories[tenant.slug] || []
  specific_cats.each do |cat_attrs|
    category = Category.find_or_initialize_by(site: site, key: cat_attrs[:key])
    category.assign_attributes(cat_attrs.merge(tenant: tenant, allow_paths: true))
    category.save!
  end

  puts "  ✓ Categories for #{tenant.title}: #{Category.where(site: site).count}"
end

puts "Extended categories seeding complete!"

# =============================================
# JOB LISTING SOURCES SEEDING
# =============================================

puts "\n=== Seeding Job Listing Sources ==="

job_source_configs = {
  "ai" => {
    name: "AI Jobs",
    query: "AI engineer OR machine learning engineer OR data scientist",
    location: "United States"
  },
  "construction" => {
    name: "Construction Jobs",
    query: "construction manager OR site supervisor OR project engineer construction",
    location: "United States"
  }
  # Note: dayz doesn't need job listings
}

job_source_configs.each do |tenant_slug, config|
  tenant = Tenant.find_by(slug: tenant_slug)
  next unless tenant

  site = tenant.sites.find_by(slug: tenant_slug) || tenant.sites.first
  next unless site

  source = Source.find_or_initialize_by(site: site, name: config[:name])
  source.assign_attributes(
    tenant: tenant,
    kind: :serp_api_google_jobs,
    enabled: true,
    config: {
      query: config[:query],
      location: config[:location],
      max_results: 30
    },
    schedule: { interval_seconds: 14400 },  # 4 hours
    quality_weight: 1.0
  )
  source.save!
  puts "  ✓ Created/updated job source for #{tenant.title}: #{source.name}"
end

puts "Job sources seeding complete!"

# =============================================
# TAXONOMIES AND TAGGING RULES SEEDING
# =============================================
#
# Taxonomies define TOPICS (what content is about).
# They are industry-specific per tenant/site.
#
# NOTE: Content FORMAT (article, tutorial, opinion, research, etc.)
# is handled by Entry.content_type, NOT by taxonomies.
# The AI editorialisation service sets content_type automatically.
#
# This gives two orthogonal filter dimensions in the feed:
#   - Topic filter (taxonomy slug) → "Show me AI Safety content"
#   - Format filter (content_type) → "Show me just tutorials"

puts "\n=== Seeding Taxonomies and Tagging Rules ==="

# Industry-specific taxonomies per tenant
tenant_taxonomies = {
  "root" => [
    { slug: "technology", name: "Technology", description: "Technology industry news and trends" },
    { slug: "startups", name: "Startups", description: "Startup ecosystem and funding" },
    { slug: "design", name: "Design", description: "UI/UX, graphic, and product design" },
    { slug: "business", name: "Business", description: "Business strategy and management" },
    { slug: "open-source", name: "Open Source", description: "Open source projects and community" },
    { slug: "developer-tools", name: "Developer Tools", description: "Tools and platforms for developers" },
    { slug: "data-privacy", name: "Data & Privacy", description: "Data management and privacy regulation" },
    { slug: "culture", name: "Culture", description: "Tech culture, remote work, and industry trends" }
  ],
  "ai" => [
    { slug: "machine-learning", name: "Machine Learning", description: "ML algorithms, training, and inference" },
    { slug: "llms", name: "Large Language Models", description: "GPT, Claude, Gemini, and other LLMs" },
    { slug: "generative-ai", name: "Generative AI", description: "Image, video, audio, and text generation" },
    { slug: "nlp", name: "Natural Language Processing", description: "Text understanding and language tasks" },
    { slug: "computer-vision", name: "Computer Vision", description: "Image recognition, detection, and visual AI" },
    { slug: "robotics", name: "Robotics & Embodied AI", description: "Physical AI, robots, and autonomous systems" },
    { slug: "ai-safety", name: "AI Safety & Ethics", description: "Alignment, bias, regulation, and responsible AI" },
    { slug: "ai-infrastructure", name: "AI Infrastructure", description: "GPUs, training clusters, MLOps, and deployment" },
    { slug: "ai-startups", name: "AI Startups", description: "AI startup funding, launches, and acquisitions" },
    { slug: "data-science", name: "Data Science", description: "Data analysis, statistics, and data engineering" },
    { slug: "ai-agents", name: "AI Agents", description: "Autonomous agents, tool use, and agentic systems" },
    { slug: "open-source-ai", name: "Open Source AI", description: "Open weights models, datasets, and frameworks" }
  ],
  "construction" => [
    { slug: "safety", name: "Safety", description: "Workplace safety, regulations, and compliance" },
    { slug: "sustainability", name: "Sustainability", description: "Green building, energy efficiency, and sustainable materials" },
    { slug: "materials", name: "Materials", description: "Building materials, concrete, steel, and composites" },
    { slug: "heavy-equipment", name: "Heavy Equipment", description: "Machinery, cranes, excavators, and fleet management" },
    { slug: "project-management", name: "Project Management", description: "Scheduling, budgeting, and delivery" },
    { slug: "building-codes", name: "Building Codes", description: "Codes, permits, inspections, and compliance" },
    { slug: "smart-buildings", name: "Smart Buildings", description: "IoT, BIM, automation, and building technology" },
    { slug: "infrastructure", name: "Infrastructure", description: "Roads, bridges, tunnels, and public works" },
    { slug: "residential", name: "Residential", description: "Housing, renovations, and residential development" },
    { slug: "commercial", name: "Commercial", description: "Commercial buildings, offices, and retail construction" }
  ],
  "dayz" => [
    { slug: "survival", name: "Survival Tips", description: "Food, water, health, and staying alive" },
    { slug: "base-building", name: "Base Building", description: "Construction, fortification, and base design" },
    { slug: "pvp", name: "PvP & Combat", description: "Player versus player tactics and combat" },
    { slug: "modding", name: "Modding", description: "Custom mods, modding tutorials, and mod reviews" },
    { slug: "server-admin", name: "Server Administration", description: "Server setup, configuration, and management" },
    { slug: "lore", name: "Lore & Story", description: "Game lore, fan fiction, and storytelling" },
    { slug: "weapons-gear", name: "Weapons & Gear", description: "Weapons, clothing, attachments, and equipment" },
    { slug: "vehicles", name: "Vehicles", description: "Cars, trucks, boats, and vehicle mechanics" },
    { slug: "updates", name: "Game Updates", description: "Patches, changelogs, and developer updates" },
    { slug: "community", name: "Community", description: "Events, groups, factions, and community highlights" }
  ]
}

# Industry-specific keyword tagging rules per tenant
# These auto-tag feed entries with the correct topic when keywords match
tenant_tagging_rules = {
  "root" => {
    "technology"      => { keywords: "software,hardware,tech,digital,computing,cloud,SaaS,platform,silicon", priority: 10 },
    "startups"        => { keywords: "startup,funding,seed round,series A,series B,YC,accelerator,venture capital,IPO,unicorn", priority: 10 },
    "design"          => { keywords: "UX,UI,design system,Figma,typography,wireframe,prototype,user experience,interface", priority: 10 },
    "business"        => { keywords: "revenue,growth,strategy,acquisition,merger,CEO,enterprise,B2B,B2C,market", priority: 20 },
    "open-source"     => { keywords: "open source,GitHub,repository,MIT license,Apache,contributor,fork,pull request,OSS", priority: 10 },
    "developer-tools" => { keywords: "IDE,CLI,SDK,API,framework,library,package,npm,gem,pip,docker,kubernetes", priority: 10 },
    "data-privacy"    => { keywords: "GDPR,privacy,data breach,encryption,compliance,regulation,data protection", priority: 10 },
    "culture"         => { keywords: "remote work,hiring,layoff,culture,diversity,burnout,workplace,career", priority: 20 }
  },
  "ai" => {
    "machine-learning" => { keywords: "machine learning,ML,training,neural network,deep learning,model,fine-tuning,inference,transformer", priority: 10 },
    "llms"             => { keywords: "GPT,Claude,Gemini,LLM,large language model,ChatGPT,Llama,Mistral,language model,foundation model", priority: 5 },
    "generative-ai"    => { keywords: "generative AI,text-to-image,Midjourney,DALL-E,Stable Diffusion,Sora,image generation,video generation,diffusion", priority: 10 },
    "nlp"              => { keywords: "NLP,natural language,text classification,sentiment analysis,tokenization,embedding,RAG,retrieval", priority: 10 },
    "computer-vision"  => { keywords: "computer vision,image recognition,object detection,segmentation,YOLO,vision model,OCR,image classification", priority: 10 },
    "robotics"         => { keywords: "robot,robotics,autonomous,self-driving,drone,embodied AI,manipulation,humanoid", priority: 10 },
    "ai-safety"        => { keywords: "AI safety,alignment,bias,regulation,responsible AI,ethics,governance,guardrail,RLHF,red team", priority: 10 },
    "ai-infrastructure" => { keywords: "GPU,NVIDIA,TPU,H100,training cluster,MLOps,inference,serving,CUDA,vLLM,deployment", priority: 10 },
    "ai-startups"      => { keywords: "AI startup,funding,raised,seed,series,valuation,AI company,launch,YC AI", priority: 15 },
    "data-science"     => { keywords: "data science,analytics,statistics,pandas,dataset,feature engineering,data pipeline,ETL,visualization", priority: 15 },
    "ai-agents"        => { keywords: "AI agent,autonomous agent,tool use,function calling,agentic,multi-agent,agent framework,MCP,orchestration", priority: 10 },
    "open-source-ai"   => { keywords: "open source model,open weights,Hugging Face,open source AI,Llama,Mistral,GGUF,safetensors", priority: 10 }
  },
  "construction" => {
    "safety"             => { keywords: "OSHA,safety,PPE,incident,hazard,fall protection,scaffold,compliance,inspection,accident", priority: 5 },
    "sustainability"     => { keywords: "sustainable,green building,LEED,energy efficient,solar,carbon,net zero,renewable,eco-friendly", priority: 10 },
    "materials"          => { keywords: "concrete,steel,timber,lumber,masonry,insulation,composite,aggregate,rebar,cement,drywall", priority: 10 },
    "heavy-equipment"    => { keywords: "excavator,crane,bulldozer,backhoe,loader,forklift,Caterpillar,Komatsu,heavy equipment,fleet", priority: 10 },
    "project-management" => { keywords: "project management,schedule,budget,Gantt,milestone,RFP,bid,estimate,construction management,delay", priority: 10 },
    "building-codes"     => { keywords: "building code,permit,inspection,zoning,IBC,fire code,ADA,compliance,regulation,code update", priority: 10 },
    "smart-buildings"    => { keywords: "BIM,IoT,smart building,automation,digital twin,sensor,Revit,3D model,prefab,modular", priority: 10 },
    "infrastructure"     => { keywords: "infrastructure,road,bridge,tunnel,highway,water,sewer,public works,civil engineering,dam", priority: 10 },
    "residential"        => { keywords: "residential,housing,home,renovation,remodel,apartment,single-family,builder,homebuilder,HOA", priority: 15 },
    "commercial"         => { keywords: "commercial,office,retail,warehouse,industrial,high-rise,mixed-use,tenant improvement,fitout", priority: 15 }
  },
  "dayz" => {
    "survival"      => { keywords: "survival,food,water,hunger,thirst,health,blood,bandage,cooking,hunting,fishing,farming", priority: 10 },
    "base-building" => { keywords: "base building,wall,gate,fence,watchtower,storage,lock,combination,code lock,fortif", priority: 10 },
    "pvp"           => { keywords: "PvP,kill,combat,firefight,sniper,ambush,raid,gunfight,military,assault", priority: 10 },
    "modding"       => { keywords: "mod,modding,addon,custom,expansion,DayZ Expansion,CF,Community Framework,Workshop", priority: 10 },
    "server-admin"  => { keywords: "server,admin,config,types.xml,spawn,loot table,restart,hosting,nitrado,cftools,RCON", priority: 10 },
    "lore"          => { keywords: "lore,story,backstory,chernarus,livonia,infected,CDF,NATO,roleplay,RP", priority: 15 },
    "weapons-gear"  => { keywords: "weapon,gun,rifle,pistol,shotgun,ammo,magazine,scope,attachment,vest,plate carrier,helmet,backpack", priority: 10 },
    "vehicles"      => { keywords: "vehicle,car,truck,ada,gunter,olga,sarka,helicopter,boat,radiator,spark plug,battery,tire", priority: 10 },
    "updates"       => { keywords: "update,patch,changelog,experimental,stable,1.26,1.25,1.24,hotfix,maintenance,devblog,status report", priority: 5 },
    "community"     => { keywords: "community,faction,group,event,server wipe,DayZ Underground,streamer,content creator", priority: 15 }
  }
}

# Also add domain-based rules for high-value sources per tenant
tenant_domain_rules = {
  "ai" => {
    "llms"          => [ "openai.com", "anthropic.com", "ai.google" ],
    "generative-ai" => [ "midjourney.com", "stability.ai" ],
    "ai-startups"   => [ "techcrunch.com/category/artificial-intelligence" ],
    "open-source-ai" => [ "huggingface.co" ]
  },
  "construction" => {
    "safety"         => [ "osha.gov" ],
    "building-codes" => [ "iccsafe.org" ]
  },
  "dayz" => {
    "updates"   => [ "dayz.com", "store.steampowered.com/news/app/221100" ],
    "community" => [ "reddit.com/r/dayz" ]
  }
}

Tenant.all.each do |tenant|
  site = tenant.sites.find_by(slug: tenant.slug) || tenant.sites.first
  next unless site

  # Clean up old format-based taxonomies that are now handled by content_type
  old_format_slugs = %w[news tools tutorials research opinion announcements]
  old_format_slugs.each do |old_slug|
    old_tax = Taxonomy.find_by(site: site, slug: old_slug)
    if old_tax
      old_tax.tagging_rules.destroy_all
      old_tax.destroy
      puts "  🗑 Removed old format-based taxonomy '#{old_slug}' from #{tenant.title}"
    end
  end

  # Get this tenant's topic taxonomies
  taxonomies_for_tenant = tenant_taxonomies[tenant.slug] || []

  # Create topic taxonomies
  created_taxonomies = {}
  taxonomies_for_tenant.each_with_index do |tax_attrs, idx|
    taxonomy = Taxonomy.find_or_initialize_by(site: site, slug: tax_attrs[:slug])
    taxonomy.assign_attributes(
      tenant: tenant,
      name: tax_attrs[:name],
      description: tax_attrs[:description],
      position: idx
    )
    taxonomy.save!
    created_taxonomies[tax_attrs[:slug]] = taxonomy
  end

  # Create keyword tagging rules
  rules_for_tenant = tenant_tagging_rules[tenant.slug] || {}
  rules_for_tenant.each do |taxonomy_slug, rule_config|
    taxonomy = created_taxonomies[taxonomy_slug]
    next unless taxonomy

    rule = TaggingRule.find_or_initialize_by(
      site: site,
      taxonomy: taxonomy,
      rule_type: :keyword
    )
    rule.assign_attributes(
      tenant: tenant,
      pattern: rule_config[:keywords],
      priority: rule_config[:priority],
      enabled: true
    )
    rule.save!
  end

  # Create domain tagging rules
  domain_rules_for_tenant = tenant_domain_rules[tenant.slug] || {}
  domain_rules_for_tenant.each do |taxonomy_slug, domains|
    taxonomy = created_taxonomies[taxonomy_slug]
    next unless taxonomy

    domains.each do |domain_pattern|
      rule = TaggingRule.find_or_initialize_by(
        site: site,
        taxonomy: taxonomy,
        rule_type: :domain,
        pattern: domain_pattern
      )
      rule.assign_attributes(
        tenant: tenant,
        priority: 5,
        enabled: true
      )
      rule.save!
    end
  end

  tax_count = Taxonomy.where(site: site).count
  rule_count = TaggingRule.where(site: site).count
  puts "  ✓ Taxonomies and rules for #{tenant.title}: #{tax_count} topics, #{rule_count} rules"
end

puts "Taxonomy and tagging rules seeding complete!"
