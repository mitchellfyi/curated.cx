# Ingestion Model - Schema Overview

## Overview

The ingestion system stores content from various sources (RSS feeds, APIs, scrapers) in a normalized format. All content is scoped to **Site**, ensuring complete isolation between different community sites.

---

## Model Hierarchy

```
Site (1) ──< (many) Source (1) ──< (many) ImportRun
                                        └─< (many) ContentItem
```

**Key Relationships**:
- Each **Site** can have multiple **Sources** (RSS feeds, API endpoints, etc.)
- Each **Source** can have multiple **ImportRuns** (batch executions)
- Each **ImportRun** creates multiple **ContentItems** (individual pieces of content)

---

## Source Model

**Purpose**: Defines what content to pull from (RSS feeds, SerpAPI queries, web scrapers, etc.)

**Key Attributes**:
- `site_id` - The site this source belongs to (scoped)
- `tenant_id` - Owner tenant (for backward compatibility)
- `kind` - Source type enum:
  - `serp_api_google_news` - Google News via SerpAPI
  - `rss` - RSS/Atom feeds
  - `api` - Custom API endpoints
  - `web_scraper` - Web scraping
- `name` - Unique name per site
- `config` (JSONB) - Source-specific configuration:
  - RSS: `{ url: "https://example.com/feed.xml" }`
  - SerpAPI: `{ api_key: "...", query: "AI news", location: "US" }`
  - API: `{ endpoint: "https://api.example.com/news", auth_token: "..." }`
  - Web Scraper: `{ url: "...", selectors: { links: "a.article-link" } }`
- `schedule` (JSONB) - Scheduling configuration:
  - `{ interval_seconds: 3600 }` - Run every hour
  - `{ cron: "@hourly" }` - Cron expression
- `enabled` - Enable/disable source
- `last_run_at` - Timestamp of last execution
- `last_status` - Last execution status (success, error, skipped)

**Scoping**: Site-scoped (via `SiteScoped` concern)

**Uniqueness**: `name` must be unique per `site_id`

---

## ImportRun Model

**Purpose**: Tracks batch execution of a source import with timing, status, errors, and counts.

**Key Attributes**:
- `site_id` - The site this import run belongs to (scoped)
- `source_id` - The source being imported
- `started_at` - When the import started (required)
- `completed_at` - When the import completed (null if still running)
- `status` - Execution status enum:
  - `running` - Currently executing
  - `completed` - Successfully completed
  - `failed` - Failed with error
- `error_message` - Error details (if failed)
- `items_count` - Total items processed
- `items_created` - New items created
- `items_updated` - Existing items updated
- `items_failed` - Items that failed to import

**Use Cases**:
- Track import performance and success rates
- Debug failed imports
- Monitor ingestion pipeline health
- Historical audit trail

**Scoping**: Site-scoped (via `SiteScoped` concern)

---

## ContentItem Model

**Purpose**: The canonical stored item representing ingested content.

**Key Attributes**:
- `site_id` - The site this content belongs to (scoped)
- `source_id` - The source that provided this content
- `url_canonical` - **Deduplication key**: Normalized canonical URL (unique per site)
- `url_raw` - Original URL from source (for audit trail)
- `title` - Content title
- `description` - Short description/summary
- `extracted_text` - Full extracted text content
- `raw_payload` (JSONB) - **Raw payload stored for audit/debugging**:
  - Original data from source (RSS entry, API response, etc.)
  - Preserved exactly as received
- `tags` (JSONB array) - Content tags (freeform and AI-generated)
- `summary` - AI-generated summary
- `published_at` - Original publication date (if available)

**Deduplication**:
- **Unique constraint**: `url_canonical` must be unique per `site_id`
- Same canonical URL cannot exist twice in the same site
- Different raw URLs that canonicalize to the same URL are deduplicated

**Scoping**: Site-scoped (via `SiteScoped` concern)

**Example**:
```ruby
# These URLs deduplicate to the same canonical URL:
url1 = "https://example.com/article?utm_source=google"
url2 = "https://example.com/article?utm_medium=email"

# Both canonicalize to:
canonical = "https://example.com/article"

# Only one ContentItem will exist per site with this canonical URL
```

---

## Data Flow

### 1. Source Definition

```ruby
site = Site.find_by(slug: "ai-news")

source = site.sources.create!(
  name: "AI Google News",
  kind: :serp_api_google_news,
  config: {
    api_key: "...",
    query: "artificial intelligence",
    location: "United States"
  },
  schedule: { interval_seconds: 3600 }
)
```

### 2. Import Execution

```ruby
# Create import run
import_run = ImportRun.create_for_source!(source)
# => #<ImportRun status: "running", started_at: "2025-01-20 12:00:00">

# Process items from source
items = fetch_items_from_source(source)

items.each do |item_data|
  # Find or create by canonical URL (deduplication)
  content_item = ContentItem.find_or_initialize_by_canonical_url(
    site: source.site,
    url_canonical: UrlCanonicaliser.canonicalize(item_data[:url]),
    source: source
  )

  # Update or create
  content_item.assign_attributes(
    url_raw: item_data[:url],
    title: item_data[:title],
    description: item_data[:description],
    raw_payload: item_data[:raw], # Store original payload
    published_at: item_data[:published_at]
  )

  content_item.save!
end

# Mark import complete
import_run.mark_completed!(
  items_created: 5,
  items_updated: 2,
  items_failed: 0
)
```

### 3. Content Access

```ruby
# Get all content for a site
site = Site.find_by(slug: "ai-news")
Current.site = site

content_items = ContentItem.all
# => Only items from this site

# Deduplication works automatically
duplicate_url = "https://example.com/article?utm_source=google"
ContentItem.find_or_initialize_by_canonical_url(
  site: site,
  url_canonical: UrlCanonicaliser.canonicalize(duplicate_url),
  source: source
)
# => Returns existing item if canonical URL already exists
```

---

## Scoping and Isolation

### Site-Level Scoping

All ingestion models use `SiteScoped` concern:

```ruby
class ContentItem < ApplicationRecord
  include SiteScoped
  # Automatic scoping to Current.site
end
```

**Isolation Guarantee**:
- ContentItems from Site A are completely invisible to Site B
- Even if both sites belong to the same Tenant
- Deduplication only applies within a single Site

### Deduplication Boundary

**Deduplication is Site-Scoped**:
- Same canonical URL can exist in multiple Sites
- Each Site maintains its own deduplication pool
- No cross-site content leakage

**Example**:
```ruby
site1 = Site.find_by(slug: "ai-news")
site2 = Site.find_by(slug: "tech-news")

# Same URL can exist in both sites
ContentItem.create!(site: site1, url_canonical: "https://example.com/article", ...)
ContentItem.create!(site: site2, url_canonical: "https://example.com/article", ...)
# => Both valid, different sites
```

---

## Raw Payload Storage

### Purpose

**Audit Trail**: Store original data exactly as received from source

**Debugging**: Investigate ingestion issues without re-fetching

**Re-processing**: Can re-process items with updated logic

### Storage Format

```ruby
content_item.raw_payload
# => {
#   "original_title" => "AI Breakthrough",
#   "original_url" => "https://example.com/article?utm_source=google",
#   "fetched_at" => "2025-01-20T12:00:00Z",
#   "source_data" => {
#     "author" => "John Doe",
#     "categories" => ["AI", "Machine Learning"],
#     "rss_entry" => { ... }
#   }
# }
```

### Usage

```ruby
# Access original data
original_url = content_item.raw_payload["original_url"]

# Debug issues
if content_item.title.blank?
  # Fallback to raw payload
  content_item.title = content_item.raw_payload["original_title"]
end

# Re-process with new logic
reprocess_item(content_item.raw_payload)
```

---

## Testing Deduplication

### Example Test

```ruby
it "prevents duplicate content items by canonical URL per site" do
  site = create(:site)
  source = create(:source, site: site)
  url = "https://example.com/article?utm_source=test"

  # Create first item
  ContentItem.create!(
    site: site,
    source: source,
    url_canonical: url,
    url_raw: url,
    raw_payload: {},
    tags: []
  )

  # Try to create duplicate
  expect {
    ContentItem.create!(
      site: site,
      source: source,
      url_canonical: url,
      url_raw: url + "&utm_medium=email",
      raw_payload: {},
      tags: []
    )
  }.to raise_error(ActiveRecord::RecordNotUnique)
end
```

---

## Summary

**Models**:
- **Source**: Defines what to pull from (per site)
- **ImportRun**: Tracks batch execution with status and counts
- **ContentItem**: Canonical stored content with deduplication

**Key Features**:
- ✅ Site-scoped for complete isolation
- ✅ Deduplication by canonical URL per Site
- ✅ Raw payload storage for audit/debugging
- ✅ Comprehensive validation and error handling

**Deduplication**:
- Unique constraint: `url_canonical` per `site_id`
- Automatic via `find_or_initialize_by_canonical_url`
- Prevents duplicate content within same Site

---

*Last Updated: 2025-01-20*
