# Mission Tasks - Outstanding Issues

This document maps the MISSION.md vision to actionable tasks based on current functionality. Tasks are organized by mission area and prioritized for v0 delivery.

## Current State Summary

✅ **Implemented:**
- Multi-tenant infrastructure (tenants, categories, listings)
- Basic listing model with URL canonicalization
- Admin interface for managing listings/categories
- Basic public views for listings
- Devise authentication
- Tenant scoping and isolation

❌ **Missing:** Most core mission features (see below)

---

## 1. Content Aggregation & Ingestion Pipeline

**Mission Requirement:** "pull the best content from across the web" via automated ingestion

### 1.1 Sources Model & Infrastructure
- [ ] Create `Source` model with fields:
  - `kind` enum: `serp_api_google_news`, `rss`, `api`, `web_scraper`
  - `name`, `config:jsonb`, `schedule:jsonb`
  - `last_run_at`, `last_status`, `enabled:boolean`
  - `tenant_id` (scoped)
- [ ] Add `source_id` foreign key to `listings` table
- [ ] Create admin interface for managing sources per tenant
- [ ] Add source quality controls (allowlists, blocklists, duplication rules)

### 1.2 Ingestion Jobs
- [ ] `FetchSerpApiNewsJob` - Query Google News via SerpAPI
- [ ] `FetchRssJob` - Parse RSS/Atom feeds (Feedjira)
- [ ] `UpsertListingsJob` - Normalize and dedupe discovered URLs
- [ ] `ScrapeMetadataJob` - Fetch page metadata (MetaInspector)
- [ ] Recurring scheduler with jitter (Solid Queue recurring jobs)
- [ ] Rate limiting and backoff logic
- [ ] Error handling and retry logic with exponential backoff

### 1.3 URL Normalization & Deduplication
- [ ] Extract `UrlCanonicaliser` service from Listing model
- [ ] Handle canonical link resolution from HTML
- [ ] Strip tracking parameters (UTM, fbclid, etc.)
- [ ] Validate URLs against category rules (root domain vs paths)
- [ ] Handle race conditions in concurrent upserts

---

## 2. AI Enrichment & Editorialization

**Mission Requirement:** "organise it into something actually useful" with AI-generated context

### 2.1 AI Services
- [ ] `Ai::Summarise` service - Generate short/medium/long summaries
- [ ] `Ai::Autotag` service - Extract keywords/topics with confidence scores
- [ ] `Ai::EntityExtract` service - Identify mentioned apps/services/companies
- [ ] AI client wrapper with timeouts, retries, and error handling
- [ ] Store model, prompt hash, token counts, cost, latency per enrichment

### 2.2 Enrichment Jobs
- [ ] `EnrichListingJob` - Chain summarise → autotag → entity_extract
- [ ] Idempotency keys: `tenant:listing:purpose:model:vN`
- [ ] Per-tenant AI budget enforcement (daily token caps)
- [ ] Feature flag per tenant for AI enrichment
- [ ] Queue backpressure when budgets exceeded

### 2.3 Editorial Context
- [ ] Generate "why it matters" context for listings
- [ ] Attribution tracking (source, author, publisher)
- [ ] Clear labeling of aggregated vs editorialized content
- [ ] Topic pages that accumulate value over time (evergreen guides)

---

## 3. Indexes (The Monetization Layer)

**Mission Requirement:** "Tools / apps directory", "Services directory", "Professionals directory", "Companies and products database", "Jobs board", "Events"

### 3.1 Tools/Apps Directory
- [ ] Ensure `apps` category exists with `allow_paths: false`
- [ ] Enforce root-domain-only uniqueness per tenant
- [ ] Tagged, comparable, searchable listings
- [ ] Comparison features (side-by-side tool comparison)
- [ ] Affiliate link support (store affiliate URLs in metadata)

### 3.2 Services Directory
- [ ] Ensure `services` category exists with `allow_paths: false`
- [ ] Support for agencies, freelancers, consultants
- [ ] Service provider profiles (richer metadata)
- [ ] Lead gen forms ("get quotes", "request intros")

### 3.3 Professionals Directory
- [ ] Create `professionals` category/model
- [ ] People worth following or hiring
- [ ] Profile pages with bio, links, expertise areas
- [ ] Connection to listings (who wrote/mentioned this)

### 3.4 Companies & Products Database
- [ ] Create `companies` model (or category)
- [ ] Track launches, updates, reviews
- [ ] Link companies to their tools/services
- [ ] Company profile pages

### 3.5 Jobs Board
- [ ] Create `jobs` category/model
- [ ] Job post fields: title, description, company, location, salary, type, posted_at
- [ ] Pay-per-post, bundles, or subscription pricing
- [ ] Job search and filtering
- [ ] Application tracking (optional)

### 3.6 Events Directory
- [ ] Create `events` category/model
- [ ] Event fields: name, description, date, location, type, url
- [ ] Calls for papers, tenders, grants (vertical-dependent)
- [ ] Event calendar view

### 3.7 Cross-linking System
- [ ] Create `listing_links` join table
- [ ] Relation types: `mentions_app`, `mentions_service`, `mentions_company`, `related_to`
- [ ] Bidirectional linking (news → entities, entities → news)
- [ ] Auto-link creation from AI entity extraction

---

## 4. Community Layer

**Mission Requirement:** "Submissions", "Upvotes and saves", "Comments and discussion", "Reputation"

### 4.1 User Submissions
- [ ] Public submission form (anyone can add links, tools, jobs)
- [ ] Submission queue for moderation (optional)
- [ ] Submission attribution (who submitted)
- [ ] Rate limiting per user/IP

### 4.2 Voting & Ranking System
- [ ] Create `votes` table (user_id, listing_id, vote_type: upvote/downvote, created_at)
- [ ] Create `saves` table (user_id, listing_id, note, created_at)
- [ ] Crowd ranking algorithm (not just chronology)
- [ ] "Hot" algorithm combining recency + votes
- [ ] Vote abuse detection (rate limits, trust tiers)

### 4.3 Comments & Discussion
- [ ] Create `comments` model (user_id, listing_id, body, parent_id for threading)
- [ ] Comment moderation tools
- [ ] Nested comment threads
- [ ] Comment voting (optional)
- [ ] Notification system for comment replies

### 4.4 Reputation System
- [ ] Track user contributions (submissions, comments, votes)
- [ ] Trust tiers based on contribution quality
- [ ] Reputation scores visible on profiles
- [ ] Privileges based on reputation (auto-approve submissions, etc.)

---

## 5. Distribution Layer

**Mission Requirement:** "Email digests", "Social distribution", "RSS", "SEO-friendly"

### 5.1 Email Digests
- [ ] Create `newsletter_subscriptions` table (user_id, tenant_id, frequency: daily/weekly, preferences:jsonb)
- [ ] `NewsletterDigestJob` - Generate and send digests
- [ ] Digest templates (daily briefing, weekly roundup)
- [ ] Topic-specific digests
- [ ] Unsubscribe handling
- [ ] Open/click rate tracking

### 5.2 Social Distribution
- [ ] Auto-posting to social platforms (Twitter, LinkedIn, etc.)
- [ ] Social media account management per tenant
- [ ] Post scheduling and guardrails (rate limits, content filters)
- [ ] Social engagement tracking (likes, shares, clicks)

### 5.3 RSS & Syndication
- [ ] RSS feed generation per tenant (`/feed.xml`)
- [ ] Category-specific feeds
- [ ] Tag-specific feeds
- [ ] Atom feed support
- [ ] Feed discovery (auto-discovery tags)

### 5.4 SEO Optimization
- [ ] XML sitemaps per tenant (`/sitemap.xml`)
- [ ] Structured data (JSON-LD) for listings, organizations
- [ ] Meta tags optimization (already partially done)
- [ ] Canonical URLs enforcement
- [ ] Robots.txt per tenant

---

## 6. Search & Discovery

**Mission Requirement:** "Searchable", "Filters", "Ranking"

### 6.1 Full-Text Search
- [ ] Add `pg_search` gem and configure
- [ ] Weighted search across title, description, body_text, tags
- [ ] Prefix/trigram matching for partial queries
- [ ] Search result ranking algorithm

### 6.2 Advanced Filtering
- [ ] Filter by category
- [ ] Filter by tag (create `tags` and `listing_tags` tables if not exists)
- [ ] Filter by source
- [ ] Filter by date range
- [ ] Filter by domain
- [ ] Saved searches (for logged-in users)

### 6.3 Ranking & Sorting
- [ ] Default: published_at desc, fallback created_at desc
- [ ] "Hot" ranking (recency + engagement)
- [ ] "Top" ranking (all-time engagement)
- [ ] Relevance ranking (for search queries)

---

## 7. The Autonomy Loop

**Mission Requirement:** "Ingest → Normalise → Rank → Editorialise → Publish + distribute → Learn"

### 7.1 Ranking/Scoring System
- [ ] Relevance scoring (source quality, freshness, engagement)
- [ ] Source quality tiers (allowlist, blocklist)
- [ ] Engagement signals (clicks, upvotes, saves, comments)
- [ ] Decay algorithm for freshness

### 7.2 Learning System
- [ ] Track user engagement (clicks, upvotes, saves, hides)
- [ ] Use engagement to tune what gets surfaced
- [ ] A/B testing framework for ranking algorithms
- [ ] Analytics dashboard for tenant admins

### 7.3 Editorial Automation
- [ ] Auto-generate context ("what it is, why it matters, who it affects")
- [ ] Source attribution automation
- [ ] Topic page generation from accumulated listings
- [ ] Weekly/monthly "best of" roundups

---

## 8. Monetization Features

**Mission Requirement:** "Affiliate links", "Sponsored placements", "Job posts", "Premium listings", "Membership", "Lead gen", "Data products"

### 8.1 Affiliate Links
- [ ] Store affiliate URLs in listing metadata
- [ ] Affiliate program management (which programs, which listings)
- [ ] Click tracking for affiliate links
- [ ] Revenue attribution

### 8.2 Sponsored Placements
- [ ] Create `sponsored_listings` table or flag
- [ ] Featured tool/service badges
- [ ] Sponsored roundup sections
- [ ] "Vendor of the week" feature
- [ ] Clear labeling of sponsored content

### 8.3 Job Post Payments
- [ ] Payment integration (Stripe)
- [ ] Pricing tiers (pay-per-post, bundles, subscriptions)
- [ ] Job post expiration and renewal
- [ ] Payment tracking and invoicing

### 8.4 Premium Listings
- [ ] Verified badge system
- [ ] Richer profile fields for premium listings
- [ ] Case studies section
- [ ] Priority ranking (clearly labeled)
- [ ] Premium listing management interface

### 8.5 Membership Tiers
- [ ] Create `memberships` table (user_id, tenant_id, tier, expires_at)
- [ ] Membership benefits:
  - Alerts and notifications
  - Saved searches
  - Deep filters
  - Briefings
  - Ad-light experience
- [ ] Membership pricing and billing

### 8.6 Lead Generation
- [ ] "Get quotes" forms
- [ ] "Request intros" forms
- [ ] Lead tracking and CRM integration
- [ ] Take-rate calculation per vertical

### 8.7 Data Products
- [ ] Trend reports generation
- [ ] Market maps
- [ ] "Top vendors" lists
- [ ] Salary snapshots
- [ ] Data product delivery (PDF, CSV, API)

---

## 9. Guardrails & Moderation

**Mission Requirement:** "Strict attribution", "Source quality controls", "Anti-gaming", "Moderation tools"

### 9.1 Attribution & Labeling
- [ ] Strict source attribution on all listings
- [ ] Clear labeling: aggregated vs editorialized
- [ ] Author/publisher credits
- [ ] Original source links

### 9.2 Source Quality Controls
- [ ] Source allowlists per tenant
- [ ] Source blocklists (global and per-tenant)
- [ ] Duplication detection and prevention
- [ ] Source reputation scoring

### 9.3 Anti-Gaming Measures
- [ ] Rate limits per user/IP for submissions/votes
- [ ] Trust tiers for users
- [ ] Vote abuse detection (patterns, bot detection)
- [ ] CAPTCHA for public submissions (optional)

### 9.4 Moderation Tools
- [ ] Moderation queue for submissions
- [ ] Flag/report system for listings/comments
- [ ] Bulk moderation actions
- [ ] Auto-moderation rules (keyword filters, etc.)
- [ ] One-person operation support (efficient workflows)

---

## 10. Success Metrics & Analytics

**Mission Requirement:** Track "Organic sessions", "Newsletter subscribers", "Contribution rate", "Revenue", "Cost to operate"

### 10.1 Analytics Tracking
- [ ] Page view tracking (tenant-aware)
- [ ] User engagement metrics (clicks, time on page)
- [ ] Newsletter metrics (subscribers, open rates, click rates)
- [ ] Contribution metrics (submissions, comments per user)
- [ ] Revenue tracking per tenant

### 10.2 Reporting Dashboard
- [ ] Tenant admin analytics dashboard
- [ ] Per-site metrics display
- [ ] Portfolio-wide metrics (for root tenant)
- [ ] Cost tracking (AI tokens, API costs)
- [ ] Time-to-operate metrics

### 10.3 SEO Metrics
- [ ] Organic search traffic tracking
- [ ] Keyword rankings (optional)
- [ ] Backlink tracking (optional)

---

## 11. Infrastructure & Operations

### 11.1 Jobs Operations
- [ ] Mission Control Jobs dashboard mount
- [ ] Queue configuration (ingestion, scrape, ai)
- [ ] Recurring job schedules with jitter
- [ ] Job failure alerts
- [ ] Manual job triggers (per-source run/retry)

### 11.2 Observability
- [ ] Structured JSON logging with correlation IDs
- [ ] Metrics: fetched/parsed/upserted counts, error rates, AI tokens/cost
- [ ] Alerts: source failures, scraping blocks, AI errors
- [ ] Health checks and monitoring

### 11.3 Cost Management
- [ ] Per-tenant daily token caps
- [ ] AI cost tracking and reporting
- [ ] API quota management (SerpAPI, etc.)
- [ ] Daily cost reports per tenant

---

## 12. UI/UX Enhancements

### 12.1 Public-Facing UI
- [ ] Infinite scroll or "Load more" for listings feed
- [ ] Turbo Frame bookmark toggles
- [ ] Search interface with filters
- [ ] Tag cloud/browsing
- [ ] Category navigation
- [ ] Mobile-responsive design improvements

### 12.2 Submission Interface
- [ ] Public submission form
- [ ] Submission success/status page
- [ ] User's submission history

### 12.3 User Profiles
- [ ] User profile pages
- [ ] User's bookmarks/saves
- [ ] User's submissions
- [ ] User's comments
- [ ] Reputation display

---

## Priority Ordering for v0

### Phase 1: Core Ingestion (Foundation)
1. Sources model & infrastructure
2. Ingestion jobs (SerpAPI, RSS)
3. URL normalization service
4. Metadata scraping job

### Phase 2: AI Enrichment
5. AI services (summarise, autotag, entity extract)
6. Enrichment jobs
7. Budget enforcement

### Phase 3: Community Basics
8. User submissions
9. Voting system
10. Comments

### Phase 4: Distribution
11. RSS feeds
12. Email digests
13. SEO optimization (sitemaps, structured data)

### Phase 5: Search & Discovery
14. Full-text search
15. Tag system
16. Advanced filtering

### Phase 6: Monetization (Post-v0)
17. Affiliate links
18. Sponsored placements
19. Jobs board
20. Premium listings

---

## Notes

- Many tasks from TODO.md are still relevant and should be integrated
- Quality gates must pass for all implementations
- Follow "boring is better" principle - simple, proven patterns
- All features must be multi-tenant aware
- i18n required for all user-facing text
- Tests required for all new functionality
