# Curated.cx – Multi‑Tenant Curation Platform

> Rails 8 + Postgres + Hotwire + Tailwind. AI‑first ingestion, enrichment, and discovery. High‑level specification (v0).

## 1. Purpose & Scope

A single Rails codebase powering many curated industry/community sites (tenants). Initial tenants: **curated.cx** (root/hub), **ainews.cx** (AI industry), **construction.cx** (construction industry). Core feature for v0: an automated **News feed** that aggregates items from multiple sources, normalises them, enriches them with AI, and makes them searchable/bookmarkable. Later phases add **Apps**, **Services**, **Jobs**, **Events**, and other resource types.

## 2. Goals

* Ship a small, maintainable v0 that demonstrates modern Rails and AI integrations.
* Keep architecture simple, modular, and tenant‑aware.
* Automate ingestion/enrichment/scheduling; minimal manual ops.
* Provide a tidy base for public code samples and employer demos.

## 3. Tenancy Model

* **Root tenant:** `curated.cx` - special designation for global admin, onboarding, documentation, and (eventually) self‑serve tenant creation.
* **Tenant identity:** stored in `tenants` with fields like `slug`, `name`, `hostname`, `canonical_domain`, `title`, `tagline/description`, `logo_url`, `theme`, `default_locale`, `settings` (JSON), `active`.
* **Isolation:** shared‑schema, row‑level scoping via `tenant_id` on all tenant‑owned records. Access controlled through a per‑request `Current.tenant` set by middleware using the request host.
* **Config overrides:** sensible app defaults in code/YAML; tenant‑level overrides persisted in DB JSON (`settings`) and cached.
* **Routing:** host‑based routing - each tenant can be a domain or subdomain (e.g. `ainews.cx`, `something.curated.cx`).

## 4. Core Domain (v0)

**Entities:**

* **Source** – where items come from. Types: `serp_api_google_news`, `rss`. Configurable per tenant. Has schedule config (frequency, enable/disable), last run status, and parse options.
* **Listing** – a normalised representation of a URL discovered from a Source. Categories start with `news` (v0), later `apps`, `services`, `jobs`, `events`.
* **Category** – governs behaviour and display rules for Listings (e.g. allow paths vs require root domain only).
* **Tag** – freeform and AI‑suggested tags for search/discovery.
* **User** – authentication and bookmarks.
* **Bookmark** – user‑to‑listing relation with optional note.

**Key behaviours:**

* **Uniqueness:** `listings.url_canonical` unique per tenant + category rules. Canonicalisation removes tracking parameters and normalises scheme/host/path.
* **Metadata scrape:** on create/update, fetch page with MetaInspector (title, description, image, site name, canonical link, published_at where possible, og/twitter cards, etc.).
* **AI enrichment:** background jobs to summarise content, extract keywords/tags, and detect referenced apps/services. Creates cross‑links when matches exist.
* **Search/Sort:** Postgres full‑text search across title/description/body/tags; default sort by published_at/ingested_at desc.

## 5. Categories – rules (initial)

* **news** – any article URL permitted (paths allowed). AI summary + tags required. May link to `apps`/`services` mentions.
* **apps** (phase 2) – represents products/tools. **Root domain only** (configurable). One listing per root domain per tenant. News that mentions an app should auto‑link here.
* **services** (phase 2) – agencies/consultancies/freelancers. **Root domain only**. One listing per root domain per tenant. News that mentions a service provider should auto‑link here.

## 6. Ingestion Pipeline (v0)

* **Source types:**

  * `serp_api_google_news` – query Google News for tenant/topic keywords (start with q="ai" for `ainews.cx`).
  * `rss` – e.g. OpenAI blog feed for `ainews.cx`; flexible for any RSS/Atom feed.
* **Scheduler:** recurring jobs per Source (hourly by default) enqueuing **FetchJob** → **ParseJob** → **UpsertListingsJob**.
* **De‑dupe:** upsert by canonical URL; skip if already present; update metadata if changed.
* **Rate/health:** backoff on error, store last run status, per‑source enable/disable; capture fetch/parse metrics.

## 7. Listing Lifecycle

1. **Discovered** from a Source with raw URL and publish date (if present).
2. **Canonicalised** and validated against category URL rules (root‑domain‑only where required).
3. **Metadata scraped** (MetaInspector) and stored.
4. **AI enrichment**:

   * Summarise content into

     * short_summary (tweet‑length)
     * medium_summary (1‑2 sentences)
     * long_summary (3‑5 bullets)
   * Generate tags/keywords; attach to Listing.
   * Extract referenced root domains; propose or auto‑create `apps`/`services` where allowed and link relationships both ways.
5. **Indexed** for search and visible in tenant feed.

## 8. Search & Discovery (v0)

* **FTS:** Postgres tsvector/tsquery over `title`, `description`, `summary`, with ranking/weights; trigram/prefix for partial matches.
* **Filters:** by category, tag, source, date range.
* **Sort:** by published/ingested date desc; secondary by rank.

## 9. UI & UX

* **Hotwire/Turbo:** fast server‑rendered flows: listing index/feed, search results, bookmark toggles, infinite‑scroll or “Load more”.
* **Tailwind:** component primitives; light brand theming per tenant (colours/logo/title/description) from `tenant.settings`.
* **Links:** primary CTA opens the original URL; a secondary “Details” page displays stored metadata/summary/links.

## 10. Auth & Accounts

* **Devise** for user auth (email/password initially; later OAuth providers).
* **Bookmarks** require login; unauthenticated bookmark attempts prompt sign‑up.
* **Roles (later):** owner/admin/editor/viewer per tenant; root admins at `curated.cx` for platform ops.

## 11. Background Jobs & Scheduling

* **Active Job** with a production‑ready adapter.
* **Recurring schedules** per Source (hourly default), plus queues for scraping and AI enrichment.
* **Operations UI** for jobs (dashboard) and per‑Source manual run/retry.

## 12. AI Services (initial contracts)

* **Summarise URL**: given a URL and stored HTML/text, produce short/medium/long summaries; store model, prompt, tokens, cost.
* **Auto‑tag**: extract keywords/topics; store confidence.
* **Entity extraction**: return candidate root domains for apps/services.
* **Rate limiting & retries:** exponential backoff; guardrails for timeouts; idempotency keys per listing.

## 13. Observability & Ops

* **Logging:** structured JSON logs for ingestion/enrichment; include `tenant`, `source_id`, `listing_id`.
* **Metrics:** counts (fetched, parsed, upserted), error rates, latency, AI token usage/cost per tenant/source.
* **Alerts:** repeated failures on a Source, sustained AI errors, scraping blocks.

## 14. Data Model (high‑level sketch, non‑exhaustive)

* `tenants(id, slug, hostname, title, description, logo_url, theme, settings:jsonb, active:boolean)`
* `categories(id, tenant_id, key, name, allow_paths:boolean, shown_fields:jsonb)`
* `sources(id, tenant_id, kind, name, config:jsonb, schedule:jsonb, last_run_at, last_status)`
* `listings(id, tenant_id, category_id, source_id, url_raw, url_canonical, domain, title, description, image_url, site_name, published_at, body_html, body_text, ai_summaries:jsonb, ai_tags:jsonb, metadata:jsonb)`
* `listing_links(id, tenant_id, from_listing_id, to_listing_id, relation)` (e.g. `mentions_app`, `mentions_service`)
* `tags(id, tenant_id, name)` and `listing_tags(listing_id, tag_id)`
* `users(id, tenant_id, email, encrypted_password, role)` (or global users with memberships)
* `bookmarks(id, tenant_id, user_id, listing_id, note)`

## 15. Configurability

* **Per‑tenant settings:** default queries for Google News/RSS, category enablement, scraping rules, UI fields to show, theme.
* **Category rules:** path policy (root‑only vs any URL), fields to display on details, enrichment behaviour, link policies.
* **Source presets:** preconfigured `serp_api_google_news` and `rss` templates with sensible defaults.

## 16. Security & Compliance (initial)

* Respect robots.txt and rate limits where applicable; store user agent string for scrapes.
* Backoff on 4xx/5xx; never hammer a host; cache fetches.
* Sanitise stored HTML; avoid executing remote scripts; strip trackers from URLs.

## 17. Admin & Root Tenant (`curated.cx`)

* Platform dashboard: tenants, sources, job queues, errors, AI costs, feature flags.
* Seed tenants: `ainews.cx`, `construction.cx` with starter sources and branding.
* Eventually: self‑serve tenant creation and billing.

## 18. Roadmap (high‑level)

**Milestone 1 – News v0**

* Tenancy plumbing, seed tenants, Source ingestion (SerpAPI + RSS), Listing model, metadata scraping, search, bookmarks, minimal UI.

**Milestone 2 – AI enrichment**

* Summaries, tags, entity extraction; link News → Apps/Services; per‑tenant analytics/ops UI.

**Milestone 3 – Apps & Services**

* Enforce root‑domain rules; backfill from News mentions; category pages and filters.

**Milestone 4 – Jobs & Events (optional)**

* New categories and sources; tenant‑specific presets.

**Milestone 5 – Self‑serve + Docs**

* Root tenant UI for onboarding new tenants; public docs; developer showcase sections.

## 19. Non‑Goals (for now)

* Multi‑DB or schema‑per‑tenant isolation; external search engines; heavy moderation workflows; user‑generated posts.

## 20. Open Questions

* Do we want a global `users` table with `memberships` for multi‑tenant access, or duplicate users per tenant?
* Per‑tenant AI model selection and budgets?
* Where to store raw fetched HTML for reproducible AI runs (S3 vs DB)?
* Allow manual curation/edits on Listings, or keep fully automated + override fields?

---

**Appendix: Operational Defaults (proposed)**

* **Scheduler:** hourly per Source; jitter to avoid thundering herd.
* **Job queues:** `ingestion`, `scrape`, `ai` with concurrency caps.
* **Feature flags:** `ai_enrichment`, `apps_category`, `services_category` toggled per tenant.
* **Docs:** `/docs` directory with ADRs and runbooks; seeds for demo data and smoke tests.
