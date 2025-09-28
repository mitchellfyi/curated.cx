# TODO.md – Curated.cx v0 Roadmap

High‑signal, copy‑pastable steps from multi‑tenancy onward. Rails 8 + Postgres + Hotwire + Tailwind + Devise. Jobs via Solid Queue. Host‑based multi‑tenancy with row scoping. Keep slices small and verifiable.

## MANDATORY QUALITY PROTOCOL

**BEFORE implementing ANY task below:**
1. ✅ Run `./script/dev/quality` and ensure 100% pass rate
2. ✅ Review quality standards in `doc/QUALITY_ENFORCEMENT.md`
3. ✅ Plan implementation with quality gates in mind
4. ✅ **AFTER each change**: Re-run `./script/dev/quality`
5. ✅ Only proceed when all quality checks pass

**NO EXCEPTIONS**: Quality failures block all development work.

---

## 4) Sources & Ingestion (SerpApi + RSS)

* [ ] Model `Source`: `kind` enum (`serp_api_google_news`, `rss`), `name`, `config:jsonb`, `schedule:jsonb`, `last_run_at`, `last_status`.
* [ ] Jobs: `FetchSerpApiNewsJob`, `FetchRssJob`, `UpsertListingsJob`.
* [ ] Hourly schedule per Source; jitter; enable/disable.
* [ ] rails credentials: serpapi: :api_key

**Commands**

```bash
bin/rails g model Source tenant:references kind:string name:string config:jsonb schedule:jsonb last_run_at:datetime last_status:string
bin/rails g job FetchSerpApiNews
bin/rails g job FetchRss
bin/rails g job UpsertListings
```

**Seed sources**

```ruby
Tenant.find_by!(slug: "ainews").sources.upsert_all([
  {kind: "serp_api_google_news", name: "AI Google News", config: { q: "ai", gl: "gb" }, schedule: { cron: "@hourly" }},
  {kind: "rss", name: "OpenAI Blog", config: { url: "https://openai.com/blog/rss" }, schedule: { cron: "@hourly" }}
], unique_by: %i[tenant_id name])
```

### Agent prompt

**Context:** Two fetchers feed a normaliser; jobs must be idempotent and rate limited.
**Goal:** Implement source models and three jobs to fetch raw items and upsert listings.
**Inputs:** SerpApi key; RSS URLs; tenant sources.
**Tasks:**

1. Implement `FetchSerpApiNewsJob` to call SerpApi Google News with config (q, gl, when), map to `raw_item` structs.
2. Implement `FetchRssJob` using Feedjira; emit `raw_item`s.
3. Implement `UpsertListingsJob` to canonicalise URL, find/create listing, enqueue `ScrapeMetadataJob`.
4. Store `last_run_at` and status; add simple backoff and jitter.
   **Deliverables:** Jobs, minimal client wrappers, success/error logging.
   **Acceptance:** After a run, new listings exist for AI tenant from SerpApi and OpenAI RSS; duplicates are skipped.

---

## 5) URL Canonicaliser & De‑dupe

* [ ] Service `UrlCanonicaliser` - normalise scheme/host, strip UTM params, collapse trailing slashes, resolve canonical link if present.
* [ ] Validate per category (root domain vs path allowed). Extract `domain` (`public_suffix` gem optional).
* [ ] Enforce uniqueness at DB; handle race via retry on unique violation.

**Files**

* `app/services/url_canonicaliser.rb`
* `spec/services/url_canonicaliser_spec.rb`

### Agent prompt

**Context:** Many sources produce noisy URLs; we need deterministic canonical forms.
**Goal:** Build a pure function to canonicalise and validate URLs, then apply it in upserts.
**Inputs:** Raw URLs from fetchers; category rules.
**Tasks:** Implement canonicaliser with tests for common trackers (utm_*, fbclid), http→https, trailing slash, lowercase host, canonical link override.
**Deliverables:** Service + spec; used in `UpsertListingsJob`.
**Acceptance:** Given sample inputs, outputs match fixtures; duplicates resolve to one canonical URL.

---

## 6) Scrape Metadata (MetaInspector)

* [ ] Job `ScrapeMetadataJob` - fetch with timeouts, custom UA, robots check; store OG/Twitter tags.
* [ ] Cache responses; retry with backoff; mark blocked hosts.
* [ ] Update `published_at` if trustworthy.

**Commands**

```bash
bin/rails g job ScrapeMetadata
```

### Agent prompt

**Context:** We enrich listings with title/desc/image/site/published_at.
**Goal:** Implement resilient scraping that respects robots and timeouts.
**Inputs:** Listing `url_canonical`.
**Tasks:** Fetch HTML with Faraday/Net::HTTP (timeouts), pass to MetaInspector; store fields; set `body_text` via readability extraction optional.
**Deliverables:** Job + tests with VCR cassettes.
**Acceptance:** For known URLs, metadata fields are populated and cached; failures are retried then marked.

---

## 7) AI Enrichment (async)

* [ ] Services: `Ai::Summarise`, `Ai::Autotag`, `Ai::EntityExtract`.
* [ ] Job chain per listing: summarise → autotag → entity_extract; idempotency keys `tenant:listing:purpose:model:vN`.
* [ ] Store: model, prompt hash, token counts, cost, latency; feature flag per tenant.

**ENV**

```
OPENAI_API_KEY=
AI_MODEL_SUMMARY=gpt-4o-mini
AI_MODEL_TAGS=gpt-4o-mini
AI_MODEL_ENTITIES=gpt-4o-mini
AI_MAX_TOKENS_PER_TENANT_DAY=500000
```

### Agent prompt

**Context:** All LLM calls are async and budgeted.
**Goal:** Add three AI services with strict I/O contracts and budgeting.
**Inputs:** Listing text/HTML; chosen models.
**Tasks:** Implement client wrapper with timeouts and retries; generate short/medium/long summaries; tags with confidence; extract root domains mentioned.
**Deliverables:** Services + jobs + tests (stubbed clients); per-tenant budget enforcement.
**Acceptance:** New listings get summaries/tags; entity candidates appear; budgets cap further runs.

---

## 8) Apps & Services (Phase 2) + Cross‑links

* [ ] Create categories `apps`, `services` with `allow_paths:false`.
* [ ] `listing_links` join with `relation` enum: `mentions_app`, `mentions_service`, `related_to`.
* [ ] Backfill: for extracted root domains, upsert App/Service listings and link both ways.

**Commands**

```bash
bin/rails g model ListingLink tenant:references from_listing:references to_listing:references relation:string
```

### Agent prompt

**Context:** News mentions should connect to entities (apps/services) by root domain.
**Goal:** Create entity categories and bidirectional links; enforce root-domain uniqueness.
**Inputs:** Entity candidates from AI; category rules.
**Tasks:** Add models/migrations; ensure one listing per root domain per category; add link creation job.
**Deliverables:** Models, link job, UI badges linking between news and entities.
**Acceptance:** Mentioned app domain creates or links to `apps` listing; duplicates across tenants remain isolated.

---

## 9) Search & Filters

* [ ] Add `pg_search` to `Listing` with weighted columns and prefix search.
* [ ] Expose filter params: `category`, `tag`, `source_id`, `from`, `to`.
* [ ] Default sort: `published_at desc`, fallback `created_at desc`, then rank.

**Files**

* `app/models/listing.rb` (pg_search scopes)
* `app/controllers/listings_controller.rb` (index params → query object)
* `app/queries/listings/search_query.rb` (optional query object)

**Code (model scope sketch)**

```ruby
include PgSearch::Model
pg_search_scope :q,
  against: { title: 'A', description: 'B', body_text: 'C' },
  using: { tsearch: { prefix: true } }
```

### Agent prompt

**Context:** Fast, simple Postgres FTS for discovery.
**Goal:** Implement a single `q` scope and filterable index action.
**Inputs:** Request params; existing `Listing` fields.
**Tasks:** Add pg_search, wire controller params to query; ensure indices on filter columns.
**Deliverables:** Scope, controller action, basic view filters; tests for ranking and date filters.
**Acceptance:** Query returns expected items with correct ordering; filters compose.

---

## 10) UI (Hotwire/Tailwind)

* [ ] Tenant‑aware layout (logo, title, description from `Current.tenant`).
* [ ] `/news` index with pagination or Turbo‑streamed infinite scroll.
* [ ] Bookmark toggle as a Turbo Frame; unauthenticated prompts sign‑in.
* [ ] Listing details page with metadata and AI summaries.

**Files**

* `app/controllers/listings_controller.rb` (`index`, `show`)
* `app/views/layouts/application.html.erb`
* `app/views/listings/index.html.erb`
* `app/views/listings/_listing.html.erb`
* `app/views/listings/show.html.erb`
* `app/views/bookmarks/_toggle.html.erb`

**Routes**

```ruby
resources :listings, only: %i[index show]
resources :bookmarks, only: %i[create destroy]
root 'listings#index'
```

### Agent prompt

**Context:** Server-rendered, fast UI with Hotwire.
**Goal:** Ship a minimal, polished feed and details UX per tenant.
**Inputs:** Tenant branding; listing fields.
**Tasks:** Build index and show; add Turbo stream pagination; implement bookmark toggle; basic Tailwind styling.
**Deliverables:** Views, partials, minimal CSS; system tests for bookmark and pagination.
**Acceptance:** Infinite scroll works; toggling bookmark updates without full reload; tenant branding appears.

---

## 11) Jobs Ops (Mission Control Jobs)

* [ ] Mount dashboard at `/ops/jobs` for root tenant admins/owners only (authorize via Pundit).
* [ ] Define queues: `ingestion`, `scrape`, `ai` with concurrency caps.
* [ ] Add recurring schedules for sources with jitter.

**Files**

* `config/routes.rb` (mount)
* `app/policies/ops/jobs_policy.rb` (e.g. `index?` requires `user.has_role?(:admin, root_tenant)` or `:owner`)
* `config/initializers/solid_queue.rb`
* `config/initializers/mission_control_jobs.rb`

**Routes mount sketch**

```ruby
# config/routes.rb
scope :ops do
  authenticate :user do
    mount MissionControl::Jobs::Engine => "/jobs"
  end
end
```

**Controller guard (example)**

```ruby
# app/controllers/ops/jobs_controller.rb (wrapper or before_action in ApplicationController)
before_action do
  root = Tenant.find_by!(slug: :root)
  authorize [:ops, :jobs], :index?, policy_class: Ops::JobsPolicy if Current.tenant == root
end
```

**Policy**

```ruby
# app/policies/ops/jobs_policy.rb
module Ops
  class JobsPolicy < Struct.new(:user, :record)
    def index?
      root = Tenant.find_by!(slug: :root)
      user&.has_role?(:owner, root) || user&.has_role?(:admin, root)
    end
  end
end
```

### Agent prompt

**Context:** We need visibility and controls for background work.
**Goal:** Expose a jobs dashboard and sane queue settings.
**Inputs:** Existing jobs; admin guard.
**Tasks:** Configure Solid Queue queues and concurrency; mount Mission Control Jobs behind auth; add recurring schedules.
**Deliverables:** Initialisers, routes, access control tests.
**Acceptance:** Root admin can see running/failed jobs and retry; non-admins blocked.

---

## 12) Observability

* [ ] Structured JSON logs with correlation IDs and tenant/source/listing context.
* [ ] Metrics: fetched/parsed/upserted counts, error rates, AI tokens/cost per tenant; p95 latencies.
* [ ] Alerts: repeated source failures, scraping blocks, AI error spikes (deliver via email/webhook).

**Files**

* `config/initializers/lograge.rb` (or custom formatter)
* `app/lib/with_correlation_id.rb`
* `app/services/metrics.rb` (counter helpers; can stub for now)

### Agent prompt

**Context:** Everything should be diagnosable quickly.
**Goal:** Add minimal logging, metrics counters, and alert hooks.
**Inputs:** App logger; job events; AI client events.
**Tasks:** Configure JSON logging; inject correlation IDs per request/job; implement a `Metrics.increment` shim and call it from jobs.
**Deliverables:** Initialiser, middleware/helper, calls in jobs.
**Acceptance:** Logs include tenant and correlation_id; metrics counters increment on job runs; alert stub fires on repeated failures.

---

## 13) Docs & ADRs

* [ ] Ensure `SPEC.md`, `AGENTS.md` (principles), `README.md`, `.env.example` are current.
* [ ] ADR‑0001 Multi‑tenancy (row‑scoped + host routing).
* [ ] ADR‑0002 Jobs backend (Solid Queue) + Mission Control dashboard.
* [ ] Runbooks: "Ingestion stuck", "SerpApi quota", "Robots/blocked host", "AI cost cap hit".

**Files**

* `docs/adr/0001-multi-tenancy.md`
* `docs/adr/0002-jobs-ops.md`
* `docs/runbooks/ingestion-stuck.md`

### Agent prompt

**Context:** Future you must understand decisions and operations instantly.
**Goal:** Create ADRs and runbooks with clear context and rollback steps.
**Inputs:** Decisions made above; operational defaults.
**Tasks:** Write ADRs with context/decision/consequences; runbooks with diagnosis steps and commands.
**Deliverables:** Markdown docs committed with links from README.
**Acceptance:** A reader can recover ingestion within 10 minutes using the runbook.

---

## 14) Tests (Minitest or RSpec)

* [ ] Models: tenant scoping; listing URL uniqueness; category policy; membership roles.
* [ ] Services: canonicaliser; summarise/autotag/entity extract (stub LLM); scraper respects timeouts/robots.
* [ ] Jobs: fetchers parse → upsert; retries/backoff; idempotency.
* [ ] System: host → tenant resolution; bookmark flow; search returns expected items.

**Files**

* `spec/models/*_spec.rb`
* `spec/services/*_spec.rb`
* `spec/jobs/*_spec.rb`
* `spec/system/tenant_routing_spec.rb`
* `spec/system/bookmarks_spec.rb`
* `spec/system/search_spec.rb`

### Agent prompt

**Context:** Tests prove behaviour and allow refactors.
**Goal:** Achieve coverage on core flows with fast, deterministic specs.
**Inputs:** Factories/fixtures; VCR for HTTP.
**Tasks:** Write model/service/job/system tests above; stub external calls; add simple CI script to run them.
**Deliverables:** Passing test suite; CI config executes specs on PRs.
**Acceptance:** Suite passes locally and in CI; flaky tests eliminated.

---

## 15) Seeds & Fixtures

* [ ] Tenants and categories for root, AI, construction.
* [ ] Sources for AI tenant (SerpApi q=ai; OpenAI RSS).
* [ ] Sample listings (news) for development; VCR HTTP fixtures.

**Files**

* `db/seeds.rb`
* `spec/fixtures/vcr_cassettes/*.yml`

### Agent prompt

**Context:** Dev needs realistic data quickly; tests need deterministic HTTP.
**Goal:** Provide idempotent seeds and recorded fixtures.
**Inputs:** Tenants, categories, sources; representative URLs.
**Tasks:** Implement seeds with upserts; add VCR cassettes for scraper and feeds; document `rails db:seed`.
**Deliverables:** Seeds file and fixtures.
**Acceptance:** After `db:seed`, `/news` shows items; tests run offline with VCR.

---

## 16) Security & Compliance

* [ ] Respect robots.txt; identify scraper UA; per‑host rate limit.
* [ ] Sanitize stored HTML; strip scripts; validate image URLs.
* [ ] Least‑privilege API keys; no PII beyond email for auth; secure cookies.

**Files**

* `app/services/fetcher.rb` (robots + timeouts policy)
* `config/initializers/content_security_policy.rb`

### Agent prompt

**Context:** We scrape the web and store metadata.
**Goal:** Avoid abusive behaviour and XSS; protect secrets.
**Inputs:** Fetch policy; CSP defaults.
**Tasks:** Implement robots and rate-limits; sanitize HTML via Loofah/Sanitize; configure CSP; ensure credentials are in ENV only.
**Deliverables:** Fetch policy, sanitizer, CSP config.
**Acceptance:** No inline scripts stored; CSP blocks mixed content; scraper sleeps when robots disallow.

---

## 17) Cost & Quotas

* [ ] Per‑tenant daily token caps; soft‑fail when exceeded.
* [ ] Batch AI work; reuse cached summaries; queue backpressure.
* [ ] Daily cost report per tenant and per agent.

**Files**

* `app/services/ai/budget.rb`
* `app/jobs/ai/daily_cost_report_job.rb`

### Agent prompt

**Context:** LLM spend can spike.
**Goal:** Enforce budgets and surface costs.
**Inputs:** Token → cost map; per-tenant caps.
**Tasks:** Track tokens per job; deny further AI jobs after cap; emit a daily report.
**Deliverables:** Budget service, reporting job, tests.
**Acceptance:** After cap reached, enrichment jobs are skipped with warning; daily report lists usage.

---

## 18) CI/CD & Quality Gates

* [ ] GitHub Actions: lint, audit, test matrix; DB + Solid Queue worker in CI.
* [ ] Brakeman, Bundler audit; RuboCop; coverage gate.

**Files**

* `.github/workflows/ci.yml`
* `.rubocop.yml`

### Agent prompt

**Context:** We want safe merges and reproducible results.
**Goal:** Add a single CI workflow that runs linters, audits, and tests.
**Inputs:** Gemfile; test commands; any setup scripts.
**Tasks:** Write CI YAML to start Postgres and Solid Queue worker; run `rails db:prepare` then tests; add RuboCop & security scanners.
**Deliverables:** CI workflow and lint config.
**Acceptance:** PRs show status checks; failing tests block merge.

---

## 19) Deployment

* [ ] Procfile/foreman: `web`, `css`, `js`, `jobs` workers.
* [ ] Health checks; `rails db:prepare` on boot; idempotent seeds for tenants.
* [ ] Domain config for tenants; force SSL in prod.

**Files**

* `Procfile`
* `config/puma.rb`
* `config/environments/production.rb`

### Agent prompt

**Context:** Minimal platform-agnostic deploy (Render/Fly/Heroku-like).
**Goal:** Run web and job workers; ensure migrations/seeds run safely.
**Inputs:** Procfile; env vars.
**Tasks:** Add Procfile entries, health endpoint, SSL enforcement; document deploy steps.
**Deliverables:** Files above + README deploy section.
**Acceptance:** App boots with jobs worker; first boot prepares DB and seeds tenants.

---

## 20) Verification per slice

* [ ] Green tests; `rails db:prepare` on a clean DB.
* [ ] Host header resolves to correct tenant landing page.
* [ ] `/news` shows feed; bookmarking prompts login; search returns results.
* [ ] Jobs dashboard shows activity; failure alerts fire on simulated errors.

### Agent prompt

**Context:** Each slice must be demonstrably done.
**Goal:** Provide a reproducible checklist to verify functionality.
**Inputs:** Local dev environment.
**Tasks:** Document exact commands and pages to check per slice; include rollback instructions.
**Deliverables:** Verification checklist in README or per-slice notes.
**Acceptance:** Another developer can verify completion without asking questions.

---

## 21) Rollback

* Revert deploy; `rails db:rollback STEP=n` for faulty migrations.
* Disable failing Sources; pause queues; flip feature flags.
* Rebuild indexes if corruption suspected; replay jobs idempotently.

### Agent prompt

**Context:** We need safe exits when something breaks.
**Goal:** Define exact steps to back out failures.
**Inputs:** Git history; migrations; feature flags.
**Tasks:** Write a rollback playbook; include commands and how to re-run jobs safely.
**Deliverables:** Runbook section and verified steps.
**Acceptance:** You can restore previous version and data integrity within minutes.

---

## 22) Backlog / Nice‑to‑haves

* Tenant self‑serve creation at `curated.cx` root.
* Per‑tenant theme editor (colours/logo).
* Jobs & Events categories.
* Webhooks for new listing events.
* API keys for read‑only consumer apps.

### Agent prompt

**Context:** Later enhancements that shouldn’t block v0.
**Goal:** Keep a groomed backlog with clear acceptance hints.
**Tasks:** For each item, add a one-line outcome and dependencies; defer until core is stable.
