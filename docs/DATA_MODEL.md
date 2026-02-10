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
                 └──< (many) Entry (1) ──< (many) AffiliateClick
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
- `has_many :entries` - Legacy association (may be moved to Site in future)

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

### Entry (Unified Content)

**Purpose**: Represents all curated content—unified model with `entry_kind` discriminator. Replaces the former ContentItem and Listing models.

**Entry kinds**:
- `feed` (was ContentItem) - Ingested content (articles, tutorials, etc.)
- `directory` (was Listing) - Curated directory items (tools, jobs, services)

**Common Attributes** (all entries):
- `site_id` - The site this entry belongs to
- `tenant_id` - Legacy association (set from site)
- `entry_kind` - Enum: `feed`, `directory`
- `title`, `description`, `body_html` - Content fields
- `url_canonical`, `url_raw` - Source URLs
- `published_at` - Publication timestamp

**Feed entry attributes** (entry_kind: feed):
- `source_id` - Ingestion source
- `raw_payload` (JSONB) - Original ingested data
- `tags` - Raw source tags
- `enrichment_status` - Metadata enrichment state
- `ai_summary` - AI-generated summary
- `topic_tags` (JSONB) - Taxonomy slugs
- `content_type` - Format (article, tutorial, etc.)

**Directory entry attributes** (entry_kind: directory):
- `category_id` - Content category
- `listing_type` - Enum: `tool`, `job`, `service`
- `company`, `location`, `salary_range`, `apply_url` - Job fields
- `affiliate_url_template` - Affiliate URL with placeholders
- `affiliate_attribution` (JSONB) - Tracking parameters
- `featured_from`, `featured_until` - Featured date range
- `featured_by_id` - Admin who set featured
- `expires_at` - Expiry for jobs
- `paid`, `payment_status` - Payment tracking

**Associations**:
- `belongs_to :site` - Parent site
- `belongs_to :tenant` - Legacy association
- `belongs_to :category` (directory entries) - Content category
- `belongs_to :source` (feed entries) - Ingestion source
- `belongs_to :featured_by` (User) - Admin reference
- `has_many :affiliate_clicks` - Click tracking

**Scopes**:
- `published` - Has `published_at`
- `feed` / `directory` - By entry kind
- `featured` - Currently within featured date range (directory)
- `not_expired` - Not past `expires_at` (directory)
- `jobs`, `tools`, `services` - By listing type (directory)
- `active_jobs` - Jobs that are published and not expired (directory)
- `with_affiliate` - Has affiliate template configured

**Example**:
```ruby
# Create a featured job entry (directory)
entry = site.entries.create!(
  entry_kind: :directory,
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
entry.featured?  # => true
entry.expired?   # => false
entry.job?       # => true
```

---

### AffiliateClick (Click Tracking)

**Purpose**: Tracks clicks on affiliate links for revenue analytics.

**Key Attributes**:
- `entry_id` - The clicked entry
- `clicked_at` - Timestamp of click
- `ip_hash` - SHA256 hash of IP (privacy)
- `user_agent` - Browser information
- `referrer` - Source page URL

**Associations**:
- `belongs_to :entry` - Parent entry

**Scopes**:
- `recent` - Ordered by most recent
- `today`, `this_week`, `this_month` - Time-based filtering
- `for_site(site_id)` - Scoped to a site via entry

**Example**:
```ruby
# Track a click
AffiliateClick.create!(
  entry: entry,
  clicked_at: Time.current,
  ip_hash: Digest::SHA256.hexdigest(ip)[0..15],
  user_agent: request.user_agent,
  referrer: request.referrer
)

# Analytics
AffiliateClick.for_site(site.id).this_month.count
AffiliateClick.count_by_entry(site_id: site.id, since: 30.days.ago)
```

---

## Migration Path

**Current State**: The application currently uses `Tenant` model directly with `hostname` field for routing.

**Future State**:
- Sites will be the primary entity for content (Categories, Entries will belong to Site)
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

### Flag (Content Reporting)

**Purpose**: Represents a user's report of problematic content, comments, notes, or discussion posts.

**Key Attributes**:
- `site_id` - Site this flag belongs to
- `user_id` - User who created the flag
- `flaggable_type` / `flaggable_id` - Polymorphic reference (Entry, Comment, Note, DiscussionPost)
- `reason` - Enum: `spam`, `harassment`, `misinformation`, `inappropriate`, `other`
- `status` - Enum: `pending`, `reviewed`, `dismissed`, `action_taken`
- `details` - Optional explanation (max 1000 chars)
- `reviewed_by_id` - Admin who reviewed the flag
- `reviewed_at` - When the flag was reviewed

**Associations**:
- `belongs_to :site` - Site context
- `belongs_to :user` - Reporter
- `belongs_to :flaggable` - Polymorphic (Entry, Comment, Note, DiscussionPost)
- `belongs_to :reviewed_by` (User) - Admin reference

**Scopes**:
- `pending` - Awaiting review
- `resolved` - Already reviewed (any status except pending)
- `for_entries` - Flags on Entry
- `for_comments` - Flags on Comment
- `for_notes` - Flags on Note
- `recent` - Ordered by newest first

**Example**:
```ruby
# Flag an entry for spam
flag = Flag.create!(
  site: Current.site,
  user: current_user,
  flaggable: entry,
  reason: :spam,
  details: "Promoting a product"
)

# Admin dismisses the flag
flag.dismiss!(admin_user)

# Admin resolves with action taken
flag.resolve!(admin_user, action: :action_taken)
```

---

### Discussion (Community Thread)

**Purpose**: Represents a standalone community discussion thread where users can engage in conversations independent of content items.

**Key Attributes**:
- `site_id` - Site this discussion belongs to
- `user_id` - User who created the discussion
- `title` - Discussion title (max 200 chars)
- `body` - Optional description/introduction (max 10,000 chars)
- `visibility` - Enum: `public_access` (anyone can view), `subscribers_only` (requires DigestSubscription)
- `pinned` - Boolean (appears first in listings)
- `pinned_at` - When pinned
- `locked_at` - When locked (no new posts)
- `locked_by_id` - Admin who locked the discussion
- `posts_count` - Counter cache of DiscussionPosts
- `last_post_at` - Last activity timestamp (for sorting)

**Associations**:
- `belongs_to :site` (via SiteScoped)
- `belongs_to :user` - Creator
- `belongs_to :locked_by` (User, optional) - Admin who locked
- `has_many :posts` (DiscussionPost) - Discussion posts

**Scopes**:
- `pinned_first` - Pinned DESC, then by activity
- `recent_activity` - Ordered by last_post_at
- `publicly_visible` - Public discussions only
- `unlocked` - Discussions that aren't locked

**Methods**:
- `locked?` - Whether discussion is locked
- `lock!(user)` - Lock the discussion
- `unlock!` - Unlock the discussion
- `pin!` - Pin to top of listings
- `unpin!` - Remove pin
- `touch_last_post!` - Update last_post_at

**Example**:
```ruby
# Create a discussion
discussion = Discussion.create!(
  site: Current.site,
  user: current_user,
  title: "Welcome to our community!",
  body: "Introduce yourself here...",
  visibility: :public_access
)

# Pin it (admin)
discussion.pin!

# Lock when needed (admin)
discussion.lock!(admin_user)
discussion.locked?  # => true
```

---

### DiscussionPost (Discussion Message)

**Purpose**: Represents a single post/message within a discussion, supporting flat threading (one level of replies).

**Key Attributes**:
- `site_id` - Site this post belongs to
- `discussion_id` - Parent discussion
- `user_id` - Author
- `body` - Post content (max 10,000 chars)
- `parent_id` - Parent post for replies (nil for root posts)
- `edited_at` - When post was edited
- `hidden_at` - When post was hidden (for moderation)

**Associations**:
- `belongs_to :site` (via SiteScoped)
- `belongs_to :user` - Author
- `belongs_to :discussion` (counter_cache: :posts_count)
- `belongs_to :parent` (DiscussionPost, optional) - Parent post for replies
- `has_many :replies` (DiscussionPost) - Child replies
- `has_many :flags` (as: :flaggable) - User reports

**Scopes**:
- `root_posts` - Top-level posts (parent_id nil)
- `oldest_first` - Chronological order
- `recent` - Reverse chronological
- `visible` - Not hidden

**Callbacks**:
- `after_create :touch_discussion_last_post` - Updates discussion's last_post_at

**Methods**:
- `root?` - Is this a top-level post?
- `reply?` - Is this a reply to another post?
- `edited?` - Has this post been edited?
- `hidden?` - Is this post hidden?
- `mark_as_edited!` - Set edited_at timestamp

**Example**:
```ruby
# Create a post in a discussion
post = DiscussionPost.create!(
  site: Current.site,
  discussion: discussion,
  user: current_user,
  body: "This is my contribution to the discussion."
)

# Reply to the post
reply = DiscussionPost.create!(
  site: Current.site,
  discussion: discussion,
  user: another_user,
  parent: post,
  body: "Great point! I agree."
)

# Check relationships
post.root?    # => true
reply.reply?  # => true
reply.parent  # => post
post.replies  # => [reply]
```

---

### DigestSubscription (Newsletter Subscription)

**Purpose**: Represents a user's subscription to a site's newsletter digest.

**Key Attributes**:
- `site_id` - Site this subscription belongs to
- `user_id` - Subscriber user account
- `frequency` - Enum: `weekly`, `daily`
- `active` - Boolean subscription status
- `referral_code` - Unique code for referral program (auto-generated)
- `unsubscribe_token` - Token for unsubscribe links
- `last_sent_at` - Last digest sent timestamp
- `preferences` (JSONB) - Content preferences

**Associations**:
- `belongs_to :site` - Parent site
- `belongs_to :user` - Subscriber
- `has_many :referrals_as_referrer` (Referral) - Referrals made by this subscriber
- `has_one :referral_as_referee` (Referral) - Referral that created this subscription
- `has_many :subscriber_taggings` - Tag assignments
- `has_many :subscriber_tags, through: :subscriber_taggings` - Tags for segmentation

**Scopes**:
- `active` - Active subscriptions
- `due_for_weekly` - Weekly digests ready to send
- `due_for_daily` - Daily digests ready to send

**Example**:
```ruby
# Create subscription with auto-generated referral code
subscription = DigestSubscription.create!(
  site: site,
  user: user,
  frequency: :weekly
)

# Get shareable referral link
subscription.referral_link  # => "https://ainews.cx/subscribe?ref=abc123xyz"

# Check referral stats
subscription.confirmed_referrals_count  # => 5

# Tag for segmentation
subscription.subscriber_tags << SubscriberTag.find_by(slug: "vip")
```

---

### SubscriberSegment (Segment Definition)

**Purpose**: Defines a segment of subscribers using rule-based criteria for targeted digest sends.

**Key Attributes**:
- `site_id` - Site this segment belongs to
- `tenant_id` - Tenant context
- `name` - Display name (e.g., "Power Users")
- `description` - Optional description
- `rules` (JSONB) - Rule criteria for filtering subscribers
- `system_segment` - Boolean flag for system-created segments (non-editable)
- `enabled` - Boolean to enable/disable segment

**Rules Format** (JSONB):
```json
{
  "subscription_age": { "min_days": 7, "max_days": null },
  "engagement_level": { "min_actions": 5, "within_days": 30 },
  "referral_count": { "min": 3 },
  "tags": { "any": ["vip", "beta"], "all": [] },
  "frequency": "weekly",
  "active": true
}
```

**Associations**:
- `belongs_to :site` (via SiteScoped)
- `belongs_to :tenant`

**Scopes**:
- `enabled` - Active segments
- `system` - System-created segments
- `custom` - User-created segments (non-system)

**Methods**:
- `editable?` - Returns false for system segments
- `rules` - Returns JSONB rules or empty hash
- `subscribers_count` - Returns count of matching subscribers via SegmentationService

**System Segments** (auto-created on site creation):
1. "All Subscribers" - rules: `{}`
2. "Active (30 days)" - rules: `{ "engagement_level": { "min_actions": 1, "within_days": 30 } }`
3. "New (7 days)" - rules: `{ "subscription_age": { "max_days": 7 } }`
4. "Power Users" - rules: `{ "referral_count": { "min": 3 } }`

**Example**:
```ruby
# Create a custom segment
segment = SubscriberSegment.create!(
  site: site,
  name: "VIP Weekly Subscribers",
  rules: {
    tags: { any: ["vip"] },
    frequency: "weekly",
    active: true
  }
)

# Get matching subscribers
SegmentationService.subscribers_for(segment)  # => ActiveRecord::Relation

# Check subscriber count
segment.subscribers_count  # => 42
```

---

### SubscriberTag (Manual Tag)

**Purpose**: Represents a tag that can be assigned to subscribers for custom segmentation.

**Key Attributes**:
- `site_id` - Site this tag belongs to
- `tenant_id` - Tenant context
- `name` - Display name (e.g., "VIP")
- `slug` - URL-friendly identifier (auto-generated)

**Associations**:
- `belongs_to :site` (via SiteScoped)
- `belongs_to :tenant`
- `has_many :subscriber_taggings, dependent: :destroy`
- `has_many :digest_subscriptions, through: :subscriber_taggings`

**Callbacks**:
- `before_validation :generate_slug` - Auto-generates slug from name

**Scopes**:
- `alphabetical` - Ordered by name

**Example**:
```ruby
# Create a tag
tag = SubscriberTag.create!(site: site, name: "Beta Tester")
tag.slug  # => "beta-tester"

# Assign to subscriber
subscription.subscriber_tags << tag

# Use in segment rules
segment = SubscriberSegment.create!(
  site: site,
  name: "Beta Users",
  rules: { tags: { any: ["beta-tester"] } }
)
```

---

### SubscriberTagging (Tag Assignment)

**Purpose**: Join model linking subscribers to tags.

**Key Attributes**:
- `digest_subscription_id` - The subscriber
- `subscriber_tag_id` - The tag

**Associations**:
- `belongs_to :digest_subscription`
- `belongs_to :subscriber_tag`

**Constraints**:
- Unique index on `(digest_subscription_id, subscriber_tag_id)`

**Example**:
```ruby
# Assign tag to subscriber
SubscriberTagging.create!(
  digest_subscription: subscription,
  subscriber_tag: vip_tag
)

# Or via association
subscription.subscriber_tags << vip_tag
```

---

### Referral (Referral Tracking)

**Purpose**: Tracks subscriber referrals for the referral program.

**Key Attributes**:
- `site_id` - Site context
- `referrer_subscription_id` - Subscription that made the referral
- `referee_subscription_id` - New subscription created via referral (unique)
- `status` - Enum: `pending`, `confirmed`, `rewarded`, `cancelled`
- `referee_ip_hash` - SHA256 hash of referee IP (fraud prevention)
- `confirmed_at` - When referral was confirmed (24h after signup)
- `rewarded_at` - When reward was granted

**Associations**:
- `belongs_to :site` - Site context
- `belongs_to :referrer_subscription` (DigestSubscription) - The referrer
- `belongs_to :referee_subscription` (DigestSubscription) - The referred subscriber

**Lifecycle**:
1. `pending` - Created when new subscriber uses referral link
2. `confirmed` - After 24h if referee subscription still active
3. `rewarded` - When referrer reaches milestone and claims reward
4. `cancelled` - If referee unsubscribes before confirmation

**Scopes**:
- `pending`, `confirmed`, `rewarded`, `cancelled` - By status
- `for_referrer(subscription)` - All referrals by a subscriber
- `recent` - Ordered by newest first

**Example**:
```ruby
# Referral created via ReferralAttributionService
referral = Referral.create!(
  site: site,
  referrer_subscription: referrer,
  referee_subscription: new_subscriber,
  referee_ip_hash: Digest::SHA256.hexdigest(ip_address)
)

# After 24h verification
referral.confirm!

# When reward tier is reached
referral.mark_rewarded!
```

---

### ReferralRewardTier (Milestone Rewards)

**Purpose**: Configures milestone-based rewards for the referral program.

**Key Attributes**:
- `site_id` - Site context
- `milestone` - Number of referrals required (unique per site)
- `reward_type` - Enum: `digital_download`, `featured_mention`, `custom`
- `name` - Display name (e.g., "Bronze Tier")
- `description` - Optional description
- `reward_data` (JSONB) - Type-specific data:
  - `download_url` - For digital downloads
  - `mention_details` - For featured mentions
  - `instructions` - For custom rewards
- `active` - Boolean to enable/disable tier

**Associations**:
- `belongs_to :site` - Site context

**Scopes**:
- `active` - Enabled tiers only
- `ordered_by_milestone` - Sorted by milestone ascending

**Example**:
```ruby
# Configure reward tiers
ReferralRewardTier.create!(
  site: site,
  milestone: 3,
  reward_type: :digital_download,
  name: "Bronze Tier",
  description: "Get our exclusive eBook",
  reward_data: { download_url: "https://example.com/ebook.pdf" }
)

ReferralRewardTier.create!(
  site: site,
  milestone: 10,
  reward_type: :featured_mention,
  name: "Gold Tier",
  description: "Get featured in our newsletter",
  reward_data: { mention_details: "Top of the newsletter for one issue" }
)
```

---

### NetworkBoost (Cross-Network Promotion)

**Purpose**: Represents a boost campaign where one site promotes another for CPC revenue.

**Key Attributes**:
- `source_site_id` - Site displaying the boost (earns revenue)
- `target_site_id` - Site being promoted (pays for clicks)
- `cpc_rate` - Cost per click in dollars
- `monthly_budget` - Monthly spend cap (nil = unlimited)
- `spent_this_month` - Current month's spend
- `enabled` - Whether boost is active

**Associations**:
- `belongs_to :source_site` (Site) - The referring site
- `belongs_to :target_site` (Site) - The promoted site
- `has_many :boost_impressions` - View tracking
- `has_many :boost_clicks` - Click tracking

**Scopes**:
- `enabled` - Active boosts only
- `with_budget` - Boosts with remaining budget
- `for_source_site(site)` - Boosts from a specific site
- `for_target_site(site)` - Boosts to a specific site

**Example**:
```ruby
# Create a boost campaign
boost = NetworkBoost.create!(
  source_site: referrer_site,
  target_site: promoted_site,
  cpc_rate: 0.50,
  monthly_budget: 100.00,
  enabled: true
)

# Check budget
boost.has_budget?      # => true
boost.remaining_budget # => 100.00

# Record a click (increments spent_this_month)
boost.record_click!
```

---

### BoostImpression (View Tracking)

**Purpose**: Tracks when boost recommendations are shown to users.

**Key Attributes**:
- `network_boost_id` - The boost campaign
- `site_id` - Where the boost was shown
- `ip_hash` - Hashed viewer IP (privacy)
- `shown_at` - When shown

**Associations**:
- `belongs_to :network_boost` - Parent campaign
- `belongs_to :site` - Where displayed

**Scopes**:
- `today`, `this_week`, `this_month` - Temporal filters
- `for_boost(boost)` - Impressions for a specific boost

**Example**:
```ruby
# Record an impression
BoostImpression.create!(
  network_boost: boost,
  site: current_site,
  ip_hash: Digest::SHA256.hexdigest(ip),
  shown_at: Time.current
)
```

---

### BoostClick (Click & Conversion Tracking)

**Purpose**: Tracks clicks on boost recommendations with conversion attribution.

**Key Attributes**:
- `network_boost_id` - The boost campaign
- `ip_hash` - Hashed clicker IP
- `clicked_at` - When clicked
- `converted_at` - When subscription was created (nil if not converted)
- `digest_subscription_id` - Resulting subscription (nil if not converted)
- `earned_amount` - CPC rate at time of click
- `status` - Enum: `pending`, `confirmed`, `paid`, `cancelled`

**Associations**:
- `belongs_to :network_boost` - Parent campaign
- `belongs_to :digest_subscription` (optional) - Resulting subscription

**Lifecycle**:
1. `pending` - Click recorded, awaiting 24h verification
2. `confirmed` - Verified after 24h delay
3. `paid` - Included in a payout
4. `cancelled` - Fraud detected or manually cancelled

**Scopes**:
- `recent`, `today`, `this_week`, `this_month` - Temporal filters
- `converted`, `unconverted` - Conversion status
- `within_attribution_window(ip_hash)` - 30-day lookback for attribution

**Example**:
```ruby
# Record a click via service
click = BoostAttributionService.record_click(
  boost: boost,
  ip: request.remote_ip
)

# After 24h verification (via ConfirmBoostClickJob)
click.confirm!

# When subscription is created
click.mark_converted!(subscription)
```

---

### BoostPayout (Payment Records)

**Purpose**: Tracks payout records for boost earnings.

**Key Attributes**:
- `site_id` - Site receiving payout
- `amount` - Payout amount in dollars
- `period_start` - Period start date
- `period_end` - Period end date
- `status` - Enum: `pending`, `paid`, `cancelled`
- `paid_at` - When paid
- `payment_reference` - External payment ID

**Associations**:
- `belongs_to :site` - Site receiving payment

**Scopes**:
- `pending`, `paid`, `cancelled` - By status
- `for_period(start, end)` - By date range

**Example**:
```ruby
# Create monthly payout
payout = BoostPayout.create!(
  site: site,
  amount: 150.00,
  period_start: 1.month.ago.beginning_of_month,
  period_end: 1.month.ago.end_of_month,
  status: :pending
)

# Mark as paid
payout.update!(status: :paid, paid_at: Time.current, payment_reference: "stripe_123")
```

---

### EmailSequence (Automation Sequence)

**Purpose**: Defines an automated email sequence triggered by subscriber lifecycle events.

**Key Attributes**:
- `site_id` - Site this sequence belongs to
- `name` - Display name (e.g., "Welcome Series")
- `trigger_type` - Enum: `subscriber_joined`, `referral_milestone`
- `trigger_config` (JSONB) - Trigger-specific settings (e.g., `{milestone: 5}`)
- `enabled` - Boolean to enable/disable sequence

**Associations**:
- `belongs_to :site` - Site context
- `has_many :email_steps` - Steps in the sequence
- `has_many :sequence_enrollments` - Subscribers enrolled in this sequence

**Scopes**:
- `enabled` - Active sequences only
- `for_trigger(type)` - Filter by trigger type

**Example**:
```ruby
# Create a welcome sequence
sequence = EmailSequence.create!(
  site: site,
  name: "Welcome Series",
  trigger_type: :subscriber_joined,
  enabled: true
)

# Add steps
sequence.email_steps.create!(
  position: 0,
  delay_seconds: 0,
  subject: "Welcome to our newsletter!",
  body_html: "<p>Thanks for subscribing...</p>"
)
```

---

### EmailStep (Sequence Step)

**Purpose**: A single email step within an automation sequence.

**Key Attributes**:
- `email_sequence_id` - Parent sequence
- `position` - Order in sequence (0-indexed)
- `delay_seconds` - Delay before sending (from enrollment or previous step)
- `subject` - Email subject line
- `body_html` - HTML email body
- `body_text` - Plain text email body (optional)

**Associations**:
- `belongs_to :email_sequence` - Parent sequence
- `has_many :sequence_emails` - Sent/scheduled instances of this step

**Scopes**:
- `ordered` - Sorted by position ascending

**Methods**:
- `delay_duration` - Returns `delay_seconds.seconds` for time calculations

**Example**:
```ruby
# First email: sent immediately after enrollment
step1 = sequence.email_steps.create!(
  position: 0,
  delay_seconds: 0,
  subject: "Welcome!",
  body_html: "<p>Welcome to our newsletter...</p>"
)

# Second email: sent 3 days later
step2 = sequence.email_steps.create!(
  position: 1,
  delay_seconds: 3.days.to_i,
  subject: "Did you miss this?",
  body_html: "<p>Here are our top stories...</p>"
)
```

---

### SequenceEnrollment (Subscriber Enrollment)

**Purpose**: Tracks a subscriber's progress through an email sequence.

**Key Attributes**:
- `email_sequence_id` - The sequence enrolled in
- `digest_subscription_id` - The enrolled subscriber
- `status` - Enum: `active`, `completed`, `stopped`
- `current_step_position` - Position of next step to send
- `enrolled_at` - Enrollment timestamp
- `completed_at` - Completion timestamp (if completed)

**Associations**:
- `belongs_to :email_sequence` - The sequence
- `belongs_to :digest_subscription` - The subscriber
- `has_many :sequence_emails` - Sent/scheduled emails

**Lifecycle**:
1. `active` - Subscriber is progressing through the sequence
2. `completed` - All steps have been sent
3. `stopped` - Subscriber unsubscribed or manually stopped

**Methods**:
- `stop!` - Stop the enrollment (e.g., when subscriber unsubscribes)
- `complete!` - Mark as completed
- `next_step` - Get the next EmailStep to send
- `schedule_next_email!` - Create SequenceEmail for next step

**Example**:
```ruby
# Enrollment happens automatically via SequenceEnrollmentService
# when subscriber_joined trigger fires

# Check enrollment status
enrollment = SequenceEnrollment.find_by(
  digest_subscription: subscription,
  email_sequence: sequence
)
enrollment.active?  # => true
enrollment.next_step  # => EmailStep for next email
```

---

### SequenceEmail (Scheduled Email)

**Purpose**: A single scheduled or sent email instance within an enrollment.

**Key Attributes**:
- `sequence_enrollment_id` - Parent enrollment
- `email_step_id` - The step being sent
- `status` - Enum: `pending`, `sent`, `failed`
- `scheduled_for` - When to send the email
- `sent_at` - When actually sent

**Associations**:
- `belongs_to :sequence_enrollment` - Parent enrollment
- `belongs_to :email_step` - The step template

**Scopes**:
- `pending` - Not yet sent
- `due` - Scheduled time has passed (`scheduled_for <= Time.current`)

**Methods**:
- `mark_sent!` - Update status to sent with timestamp
- `mark_failed!` - Update status to failed

**Example**:
```ruby
# Find due emails to process
SequenceEmail.pending.due.each do |email|
  SequenceMailer.step_email(email).deliver_later
  email.mark_sent!
end
```

---

### LiveStream (Video Stream)

**Purpose**: Represents a live video stream with Mux integration for real-time broadcasting.

**Key Attributes**:
- `site_id` - Site this stream belongs to
- `user_id` - Publisher who created the stream
- `title` - Stream title (max 200 chars)
- `description` - Optional description (max 5,000 chars)
- `scheduled_at` - When the stream is scheduled to start
- `started_at` - When the stream actually started
- `ended_at` - When the stream ended
- `status` - Enum: `scheduled`, `live`, `ended`, `archived`
- `visibility` - Enum: `public_access`, `subscribers_only`
- `mux_stream_id` - Mux live stream identifier
- `mux_playback_id` - Mux playback ID for HLS streaming
- `stream_key` - RTMP stream key (sensitive - for OBS/streaming software)
- `mux_asset_id` - Mux asset ID for replay
- `replay_playback_id` - Playback ID for recorded replay
- `viewer_count` - Current active viewers
- `peak_viewers` - Maximum concurrent viewers during stream
- `discussion_id` - Associated discussion for live chat

**Associations**:
- `belongs_to :site` (via SiteScoped)
- `belongs_to :user` - Publisher
- `belongs_to :discussion` (optional) - Live chat thread
- `has_many :viewers` (LiveStreamViewer) - Viewer analytics

**Scopes**:
- `upcoming` - Scheduled streams in the future
- `live_now` - Currently broadcasting streams
- `past` - Ended or archived streams
- `publicly_visible` - Public streams only

**Methods**:
- `live?` - Is stream currently live?
- `can_start?` / `can_end?` - Status checks
- `start!` / `end!` / `archive!` - Status transitions
- `replay_available?` - Has replay been processed?
- `playback_url` - HLS URL for live viewing
- `replay_url` - HLS URL for replay viewing
- `update_peak_viewers!` - Update peak viewer count
- `refresh_viewer_count!` - Update current viewer count

**Example**:
```ruby
# Create a scheduled stream
stream = LiveStream.create!(
  site: Current.site,
  user: current_user,
  title: "Weekly Community Hangout",
  description: "Join us for live Q&A!",
  scheduled_at: 1.day.from_now,
  visibility: :public_access
)

# Stream goes live (via webhook or manual)
stream.start!
stream.live?  # => true

# End the stream
stream.end!
stream.replay_available?  # => true (after Mux processing)
```

---

### LiveStreamViewer (Viewer Analytics)

**Purpose**: Tracks individual viewer sessions for stream analytics.

**Key Attributes**:
- `site_id` - Site context
- `live_stream_id` - The stream being watched
- `user_id` - Logged-in viewer (optional)
- `session_id` - Anonymous session identifier
- `joined_at` - When viewer joined
- `left_at` - When viewer left (nil if still watching)
- `duration_seconds` - Total watch time

**Associations**:
- `belongs_to :site` (via SiteScoped)
- `belongs_to :live_stream`
- `belongs_to :user` (optional)

**Scopes**:
- `active` - Currently watching (left_at is nil)
- `completed` - Has left the stream

**Methods**:
- `calculate_duration!` - Set duration_seconds from timestamps

**Example**:
```ruby
# Track viewer joining
viewer = LiveStreamViewer.create!(
  site: Current.site,
  live_stream: stream,
  user: current_user,
  joined_at: Time.current
)

# When viewer leaves
viewer.update!(left_at: Time.current)
viewer.calculate_duration!

# Analytics
stream.viewers.active.count  # => Current viewers
stream.peak_viewers          # => Maximum concurrent
```

---

### Note (Short-Form Content)

**Purpose**: Represents a short-form post for social-style content, similar to Substack Notes.

**Key Attributes**:
- `site_id` - Site this note belongs to
- `user_id` - Author of the note
- `body` - Note content (max 500 chars)
- `link_preview` (JSONB) - OG metadata for first URL (title, description, image, url)
- `published_at` - When published (nil = draft)
- `hidden_at` - When hidden (for moderation)
- `hidden_by_id` - Admin who hid the note
- `repost_of_id` - Original note if this is a repost
- `upvotes_count` - Counter cache for votes
- `comments_count` - Counter cache for comments
- `reposts_count` - Counter cache for reposts

**Associations**:
- `belongs_to :site` (via SiteScoped)
- `belongs_to :user` - Author
- `belongs_to :hidden_by` (User, optional) - Admin who hid the note
- `belongs_to :repost_of` (Note, optional) - Original note for reposts
- `has_many :reposts` (Note) - Notes that reposted this one
- `has_many :votes` (as: :votable) - Polymorphic votes
- `has_many :comments` (as: :commentable) - Polymorphic comments
- `has_many :bookmarks` (as: :bookmarkable) - Polymorphic bookmarks
- `has_many :flags` (as: :flaggable) - Polymorphic flags
- `has_one_attached :image` - Optional image attachment

**Scopes**:
- `published` - Notes with published_at
- `drafts` - Notes without published_at
- `not_hidden` - Notes without hidden_at
- `for_feed` - Published and not hidden
- `original` - Not reposts
- `reposts_only` - Only reposts
- `top_this_week` - By engagement in last week
- `by_engagement` - Ordered by upvotes + comments

**Methods**:
- `published?` / `draft?` - Publication status
- `hidden?` - Moderation status
- `repost?` - Is this a repost?
- `original_note` - Returns self or repost_of
- `has_link_preview?` - Has extracted OG metadata?
- `publish!` / `unpublish!` - Toggle publication
- `hide!(user)` / `unhide!` - Moderation actions

**Example**:
```ruby
# Create and publish a note
note = Note.create!(
  site: Current.site,
  user: current_user,
  body: "Excited about this new feature! Check it out: https://example.com/feature"
)
note.publish!

# Link preview is extracted automatically via ExtractNoteLinkPreviewJob
note.link_preview  # => { "title" => "...", "description" => "...", "image" => "...", "url" => "..." }

# Repost another note
repost = Note.create!(
  site: Current.site,
  user: current_user,
  body: "Great insight!",
  repost_of: original_note
)

# Engagement
note.votes.create!(site: Current.site, user: voter)
note.comments.create!(site: Current.site, user: commenter, body: "Great post!")

# Moderation
note.hide!(admin_user)
note.hidden?  # => true
```

---

## Site Configuration

The Site model uses a JSONB `config` field for flexible per-site settings. Access settings via the `setting(path, default)` method.

### Notes Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `notes.enabled` | boolean | `true` | Enable/disable Notes feature for the site |
| `digest.include_notes` | boolean | `true` | Include top notes in digest emails |

**Example**:
```ruby
site = Site.find_by_hostname!("example.cx")

# Check if notes are enabled
site.notes_enabled?        # => true
site.notes_in_digest?      # => true

# Update settings
site.update_setting("notes.enabled", false)
site.update_setting("digest.include_notes", false)
```

### Other Settings Reference

| Setting Path | Type | Default | Description |
|--------------|------|---------|-------------|
| `topics` | array | `[]` | Topic strings for the site |
| `ingestion.enabled` | boolean | `false` | Enable content ingestion |
| `ingestion.sources.*` | boolean | varies | Per-source ingestion toggles |
| `monetisation.enabled` | boolean | `false` | Enable monetisation features |
| `boosts.enabled` | boolean | `false` | Enable network boosts (income) |
| `boosts.display_enabled` | boolean | `false` | Display boost recommendations |
| `flags.notify_on_new` | boolean | `true` | Email admins on new flags |
| `analytics.enabled` | boolean | `true` | Enable analytics tracking |
| `discussions.enabled` | boolean | `true` | Enable community discussions |
| `streaming.enabled` | boolean | `false` | Enable live streaming |
| `streaming.notify_on_live` | boolean | `false` | Email subscribers when stream goes live |
| `digital_products.enabled` | boolean | `false` | Enable digital products |

---

---

## Content Classification System

The project uses three distinct, non-overlapping classification concepts:

### 1. Category (Listing Directory Sections)

**Applies to:** Directory entries only
**Purpose:** Defines the type of listing in the directory (tools, jobs, services, etc.)

- Each directory `Entry` belongs to exactly one `Category`
- Categories have a `category_type` that determines display template and behavior
- Categories are seeded per tenant with industry-specific sections

**Examples:** "Apps & Tools" (product), "Jobs" (job), "Services" (service), "AI Models" (product)

### 2. Taxonomy → topic_tags (Content Topics)

**Applies to:** Feed entries only
**Purpose:** Defines what SUBJECT the content is about. Industry-specific per tenant.

- `Taxonomy` records define available topics for a site
- `TaggingRule` records auto-assign taxonomy slugs when content matches patterns
- `Entry.topic_tags` stores matched taxonomy slugs (JSONB array, feed entries)
- AI editorialisation also suggests tags from the taxonomy list
- Users filter the feed by topic via `/feed?tag=slug`

**Examples (ainews.cx):** machine-learning, llms, generative-ai, ai-safety, ai-agents
**Examples (construction.cx):** safety, sustainability, materials, project-management
**Examples (dayz.cx):** survival, base-building, pvp, modding, updates

### 3. content_type (Content Format)

**Applies to:** Feed entries only
**Purpose:** Defines the FORMAT of the content, orthogonal to topic.

- Set by AI editorialisation (not by tagging rules)
- Stored in `Entry.content_type` (string, feed entries)
- Users filter the feed by format via `/feed?content_type=tutorial`

**Valid values:** article, tutorial, opinion, research, announcement, review, guide, interview, case-study, roundup

### How They Work Together

A content item can be filtered on two dimensions simultaneously:
- **Topic** (taxonomy): "Show me AI Safety content" → `?tag=ai-safety`
- **Format** (content_type): "Show me just tutorials" → `?content_type=tutorial`

The tagging pipeline:
1. Content is ingested → `TaggingService` applies rule-based topic tags (after_create)
2. AI editorialisation runs → sets `content_type`, suggests additional topic tags
3. Matched AI suggestions are merged into `topic_tags`

### Tag Fields on Entry (feed)

| Field | Set By | Purpose |
|-------|--------|---------|
| `topic_tags` | TaggingService + AI merge | Active topic labels (taxonomy slugs) |
| `content_type` | AI editorialisation | Format classification (article, tutorial, etc.) |
| `ai_suggested_tags` | AI editorialisation | Raw AI suggestions (for audit/review) |
| `tags` | Source ingestion | Raw source tags (preserved from original) |
| `audience_tags` | AI editorialisation | Who should read this (developers, etc.) |

---

*Last Updated: 2026-02-10* (Entry unification: merged ContentItem and Listing into unified Entry model with entry_kind discriminator. Content classification system: industry-specific taxonomies, content_type format detection, AI tag merging.)
