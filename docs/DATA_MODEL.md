# Data Model - Tenant → Site → Domain

## Overview

Curated.cx uses a three-tier data model to support portfolio-style domain ownership:

1. **Tenant** - The customer/owner account (can own multiple sites)
2. **Site** - A specific community/curation site (belongs to a tenant, can have multiple domains)
3. **Domain** - A hostname/domain name (belongs to a site, supports apex + www + subdomains)

This architecture enables:
- **Portfolio Management**: One tenant (customer) can own multiple sites (e.g., ainews.cx, construction.cx)
- **Multi-Domain Support**: Each site can have multiple domains (e.g., example.com, www.example.com, subdomain.example.com)
- **Flexible Configuration**: Site-level JSONB config for topics, ingestion sources, monetisation toggles

---

## Model Relationships

```
Tenant (1) ──< (many) Site (1) ──< (many) Domain
                 │
                 └──< (many) Listing (1) ──< (many) AffiliateClick
```

### Tenant (Owner Account)

**Purpose**: Represents a customer/owner who can manage multiple sites.

**Key Attributes**:
- `slug` - Unique identifier (e.g., "acme-corp")
- `hostname` - Legacy field (for backward compatibility)
- `title` - Display name
- `status` - enabled, disabled, private_access

**Associations**:
- `has_many :sites` - All sites owned by this tenant
- `has_many :categories` - Legacy association (may be moved to Site in future)
- `has_many :listings` - Legacy association (may be moved to Site in future)

**Example**:
```ruby
tenant = Tenant.create!(
  slug: "acme-corp",
  title: "ACME Corporation",
  status: :enabled
)

# Tenant can own multiple sites
site1 = tenant.sites.create!(slug: "ai-news", name: "AI News")
site2 = tenant.sites.create!(slug: "construction", name: "Construction News")
```

---

### Site (Community Domain)

**Purpose**: Represents a specific curated community site (e.g., ainews.cx, construction.cx).

**Key Attributes**:
- `tenant_id` - Owner of this site
- `slug` - Unique per tenant (e.g., "ai-news")
- `name` - Display name (e.g., "AI News")
- `description` - Optional description
- `config` (JSONB) - Site-specific configuration:
  - `topics` - Array of topic strings
  - `ingestion.enabled` - Toggle for content ingestion
  - `ingestion.sources` - Source-specific toggles (serp_api, rss, etc.)
  - `monetisation.enabled` - Toggle for monetisation features
- `status` - enabled, disabled, private_access

**Associations**:
- `belongs_to :tenant` - Owner account
- `has_many :domains` - All domains for this site
- `has_one :primary_domain` - The primary domain (used for canonical URLs)

**Example**:
```ruby
site = Site.create!(
  tenant: tenant,
  slug: "ai-news",
  name: "AI News",
  description: "Curated AI industry news",
  config: {
    topics: ["artificial-intelligence", "machine-learning"],
    ingestion: {
      enabled: true,
      sources: {
        serp_api: true,
        rss: true
      }
    },
    monetisation: {
      enabled: false
    }
  },
  status: :enabled
)

# Site can have multiple domains
site.domains.create!(hostname: "ainews.cx", primary: true, verified: true)
site.domains.create!(hostname: "www.ainews.cx", primary: false, verified: true)
site.domains.create!(hostname: "ai.example.com", primary: false, verified: false)
```

---

### Domain (Hostname)

**Purpose**: Represents a hostname/domain name that routes to a site.

**Key Attributes**:
- `site_id` - The site this domain belongs to
- `hostname` - The domain name (unique across all domains)
- `primary` - Boolean flag (only one primary per site)
- `verified` - Boolean flag (DNS verification status)
- `verified_at` - Timestamp of verification

**Associations**:
- `belongs_to :site` - The site this domain routes to

**Constraints**:
- Only one domain per site can be marked as `primary: true`
- Hostname must be unique across all domains
- Hostname must be valid domain format

**Example**:
```ruby
# Primary domain (apex)
domain1 = Domain.create!(
  site: site,
  hostname: "ainews.cx",
  primary: true,
  verified: true
)

# Secondary domain (www)
domain2 = Domain.create!(
  site: site,
  hostname: "www.ainews.cx",
  primary: false,
  verified: true
)

# Custom domain (unverified)
domain3 = Domain.create!(
  site: site,
  hostname: "custom-domain.com",
  primary: false,
  verified: false
)
```

---

## Why This Architecture?

### Portfolio-Style Domain Ownership

**Problem**: A customer (Tenant) may want to manage multiple curated sites, each with their own domains.

**Solution**:
- Tenant owns multiple Sites
- Each Site can have multiple Domains
- This allows one customer account to manage:
  - `ainews.cx` (AI industry site)
  - `construction.cx` (Construction industry site)
  - `tech.cx` (Tech industry site)
  - All under one Tenant account

### Multi-Domain Support

**Problem**: A site may need to support:
- Apex domain: `example.com`
- WWW variant: `www.example.com`
- Subdomains: `subdomain.example.com`
- Custom domains: `custom-domain.com`

**Solution**:
- Domain model allows multiple domains per site
- One domain marked as `primary` (for canonical URLs)
- All domains route to the same site content
- DNS verification status tracked per domain

### Flexible Configuration

**Problem**: Each site needs different settings:
- Topics/categories
- Ingestion source toggles
- Monetisation features

**Solution**:
- Site model has JSONB `config` field
- Flexible structure allows per-site customization
- Helper methods provide safe access with defaults

---

## Usage Patterns

### Creating a New Site with Domains

```ruby
# 1. Create or find tenant
tenant = Tenant.find_or_create_by!(slug: "acme-corp") do |t|
  t.title = "ACME Corporation"
  t.status = :enabled
end

# 2. Create site
site = tenant.sites.create!(
  slug: "ai-news",
  name: "AI News",
  description: "Curated AI industry news",
  config: {
    topics: ["ai", "ml"],
    ingestion: { enabled: true },
    monetisation: { enabled: false }
  }
)

# 3. Add domains
site.domains.create!(
  hostname: "ainews.cx",
  primary: true,
  verified: true
)

site.domains.create!(
  hostname: "www.ainews.cx",
  primary: false,
  verified: true
)
```

### Finding Site by Domain

```ruby
# Find site by any domain hostname
site = Site.find_by_hostname!("ainews.cx")
# or
site = Site.find_by_hostname!("www.ainews.cx")

# Both return the same site
```

### Accessing Site Configuration

```ruby
site = Site.find_by_hostname!("ainews.cx")

# Access config values
site.topics  # => ["ai", "ml"]
site.ingestion_sources_enabled?  # => true
site.monetisation_enabled?  # => false

# Update config
site.update_setting("monetisation.enabled", true)
site.monetisation_enabled?  # => true
```

### Managing Primary Domain

```ruby
site = Site.find_by_hostname!("ainews.cx")

# Get primary domain
site.primary_hostname  # => "ainews.cx"

# Change primary domain
new_primary = site.domains.find_by!(hostname: "www.ainews.cx")
new_primary.make_primary!
site.primary_hostname  # => "www.ainews.cx"
```

---

### Listing (Content Item)

**Purpose**: Represents a curated content item (tool, job, service, article).

**Key Attributes**:
- `site_id` - The site this listing belongs to
- `tenant_id` - Legacy association (set from site)
- `category_id` - Content category
- `listing_type` - Enum: `tool`, `job`, `service`
- `title`, `description`, `body_html` - Content fields
- `url_canonical`, `url_raw` - Source URLs
- `published_at` - Publication timestamp

**Monetisation Fields**:
- `affiliate_url_template` - Affiliate URL with placeholders
- `affiliate_attribution` (JSONB) - Tracking parameters
- `featured_from`, `featured_until` - Featured date range
- `featured_by_id` - Admin who set featured
- `expires_at` - Expiry for jobs
- `company`, `location`, `salary_range`, `apply_url` - Job fields
- `paid`, `payment_reference` - Payment tracking

**Associations**:
- `belongs_to :site` - Parent site
- `belongs_to :tenant` - Legacy association
- `belongs_to :category` - Content category
- `belongs_to :featured_by` (User) - Admin reference
- `has_many :affiliate_clicks` - Click tracking

**Scopes**:
- `published` - Has `published_at`
- `featured` - Currently within featured date range
- `not_expired` - Not past `expires_at`
- `jobs`, `tools`, `services` - By listing type
- `active_jobs` - Jobs that are published and not expired
- `with_affiliate` - Has affiliate template configured

**Example**:
```ruby
# Create a featured job listing
listing = site.listings.create!(
  category: jobs_category,
  listing_type: :job,
  title: "Senior Developer",
  company: "ACME Corp",
  location: "Remote",
  salary_range: "$120k-$180k",
  apply_url: "https://example.com/apply",
  url_raw: "https://example.com/jobs/123",
  expires_at: 30.days.from_now,
  featured_from: Time.current,
  featured_until: 7.days.from_now,
  published_at: Time.current
)

# Check status
listing.featured?  # => true
listing.expired?   # => false
listing.job?       # => true
```

---

### AffiliateClick (Click Tracking)

**Purpose**: Tracks clicks on affiliate links for revenue analytics.

**Key Attributes**:
- `listing_id` - The clicked listing
- `clicked_at` - Timestamp of click
- `ip_hash` - SHA256 hash of IP (privacy)
- `user_agent` - Browser information
- `referrer` - Source page URL

**Associations**:
- `belongs_to :listing` - Parent listing

**Scopes**:
- `recent` - Ordered by most recent
- `today`, `this_week`, `this_month` - Time-based filtering
- `for_site(site_id)` - Scoped to a site via listing

**Example**:
```ruby
# Track a click
AffiliateClick.create!(
  listing: listing,
  clicked_at: Time.current,
  ip_hash: Digest::SHA256.hexdigest(ip)[0..15],
  user_agent: request.user_agent,
  referrer: request.referrer
)

# Analytics
AffiliateClick.for_site(site.id).this_month.count
AffiliateClick.count_by_listing(site_id: site.id, since: 30.days.ago)
```

---

## Migration Path

**Current State**: The application currently uses `Tenant` model directly with `hostname` field for routing.

**Future State**:
- Sites will be the primary entity for content (Categories, Listings will belong to Site)
- Domains will handle all hostname routing
- Tenant will be purely the owner account

**Backward Compatibility**:
- Existing Tenant records can continue to work
- New Sites can be created from existing Tenants
- Gradual migration path available

---

## Indexes & Performance

**Site Indexes**:
- `(tenant_id, slug)` - Unique constraint for tenant-scoped slugs
- `status` - Filtering by status
- `(tenant_id, status)` - Tenant-scoped status queries

**Domain Indexes**:
- `hostname` - Unique constraint for hostname lookup
- `(site_id, primary)` - Unique constraint for single primary per site
- `(site_id, verified)` - Filtering verified domains per site

**Caching**:
- Site lookups by hostname are cached
- Cache keys: `"site:hostname:#{hostname}"`
- Cache cleared on Site/Domain updates

---

*Last Updated: 2026-01-23*
