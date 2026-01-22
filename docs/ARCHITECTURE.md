# Architecture Documentation - Curated.cx

## Overview

Curated.cx is a Rails 8 multi-tenant content aggregation platform. This document describes the current architecture, multi-tenancy implementation, job processing, deployment assumptions, and identifies gaps for future features.

---

## Multi-Tenancy Approach

### Type: **Row-Scoped Multi-Tenancy with Hostname-Based Resolution**

The application uses a **row-level scoping** approach (not schema-based separation):

- **Database Schema**: Single shared PostgreSQL database with `tenant_id` foreign keys
- **Scoping Mechanism**: `TenantScoped` concern using `acts_as_tenant` gem
- **Tenant Model**: `Tenant` model with `hostname`, `slug`, `title`, `status`, and `settings` (JSONB)

### Tenant Model Structure

```ruby
# app/models/tenant.rb
- id (primary key)
- hostname (unique, indexed) - Used for domain-based resolution
- slug (unique, indexed) - URL-friendly identifier
- title (required)
- description (optional)
- logo_url (optional)
- settings (JSONB) - Tenant-specific configuration (theme, categories, etc.)
- status (enum: enabled, disabled, private_access)
```

### Scoping Implementation

**TenantScoped Concern** (`app/models/concerns/tenant_scoped.rb`):
- Uses `acts_as_tenant :tenant` gem for automatic scoping
- Default scope: `where(tenant: Current.tenant)` when `Current.tenant` is set
- Provides `without_tenant_scope` and `for_tenant(tenant)` class methods
- Requires `belongs_to :tenant` and validates tenant presence

**Scoped Models**:
- `Listing` - includes `TenantScoped`
- `Category` - includes `TenantScoped`
- Both models have `tenant_id` foreign keys with indexes

### Tenant Isolation

- **Data Isolation**: Automatic via default scopes when `Current.tenant` is set
- **Caching**: Tenant-specific cache keys (e.g., `"tenant:hostname:#{hostname}"`)
- **Validation**: Uniqueness constraints scoped to tenant (e.g., `url_canonical` unique per tenant)
- **Acts as Tenant Config**: `require_tenant = false` - allows unscoped queries when needed

---

## Tenant Resolution Per Request

### Resolution Method: **Hostname-Based via Custom Middleware**

**Middleware**: `TenantResolver` (`app/middleware/tenant_resolver.rb`)

**Resolution Flow**:
1. **Health Check Skip**: `/up` endpoint bypasses tenant resolution
2. **Hostname Extraction**: Extracts hostname from `HTTP_HOST` header, strips port
3. **Development Mode**: Special handling for `localhost` and `*.localhost` subdomains
4. **Production Mode**: Direct hostname lookup in `tenants` table

### Resolution Logic

```ruby
# Development (localhost handling)
- "localhost" → resolves to root tenant (slug: "root")
- "ai.localhost" → resolves by slug ("ai")

# Production (hostname-based)
- "ainews.cx" → Tenant.find_by_hostname!("ainews.cx")
- "curated.cx" → Tenant.root_tenant (slug: "root")
```

### Current Context

**Current.tenant** (`config/initializers/current.rb`):
- Uses `ActiveSupport::CurrentAttributes` for request-scoped storage
- Set by `TenantResolver` middleware: `Current.tenant = tenant`
- Available throughout the request lifecycle

### Status Filtering

- **Enabled tenants**: Publicly accessible
- **Private access tenants**: Accessible but require authentication (handled in controllers)
- **Disabled tenants**: Return 404

### Error Handling

- Unknown hostnames → 404 "Tenant not found"
- Database errors → 404 "Tenant not found" (with logging)
- Missing HTTP_HOST → 404

---

## Background Job System

### System: **Solid Queue (Database-Backed)**

**Configuration**:
- **Gem**: `solid_queue` (Rails-native database-backed queue)
- **Queue Adapter**: `config.active_job.queue_adapter = :solid_queue`
- **Database**: Separate `queue` database connection (same PostgreSQL instance)
- **Schema**: `db/queue_schema.rb` with Solid Queue tables

**Worker Configuration** (`config/queue.yml`):
```yaml
default:
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: "*"
      threads: 3
      processes: <%= ENV.fetch("JOB_CONCURRENCY", 1) %>
      polling_interval: 0.1
```

### Deployment Mode

**Single-Server Mode** (`config/deploy.yml`):
- `SOLID_QUEUE_IN_PUMA: true` - Runs Solid Queue supervisor inside Puma process
- No separate job worker process by default
- Can be split to dedicated job server when scaling

**Puma Plugin** (`config/puma.rb`):
```ruby
plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]
```

### Recurring Jobs

**Configuration**: `config/recurring.yml`
- Uses Solid Queue's recurring task system
- Currently configured: `clear_solid_queue_finished_jobs` (hourly cleanup)
- Supports cron-style scheduling (e.g., "every hour at minute 12")

### Job Execution

- **Process**: `bin/jobs` - Solid Queue CLI worker
- **Integration**: Runs inline with Puma in production (single-server)
- **Threading**: 3 threads per process
- **Database**: Uses separate `queue` database connection to avoid connection pool conflicts

---

## Deployment Assumptions

### Containerization

**Dockerfile**:
- Multi-stage build (base → build → final)
- Ruby 3.4.2, PostgreSQL client, libvips, libjemalloc2
- Non-root user (rails:1000:1000)
- Entrypoint: `/rails/bin/docker-entrypoint` (runs `db:prepare` if needed)

### Deployment Platform: **Kamal (Docker-based)**

**Configuration** (`config/deploy.yml`):
- Service: `curated`
- SSL: Auto-certification via Let's Encrypt
- Proxy: Kamal proxy with SSL termination
- Environment: Secrets via `.kamal/secrets` (RAILS_MASTER_KEY)
- Volumes: `curated_storage:/rails/storage` for Active Storage

**Deployment Targets**:
- Designed for Docker hosts (Kamal SSH deployment)
- Can run on Dokku (Heroku-compatible) with minor adjustments
- Single-server deployment with optional job server separation

### Database Configuration

**Multi-Database Setup** (`config/database.yml`):
```yaml
production:
  primary: curated_production
  cache: curated_production_cache
  queue: curated_production_queue
  cable: curated_production_cable
```

**Database Adapters**:
- Primary: PostgreSQL (main application data)
- Cache: Solid Cache (database-backed caching)
- Queue: Solid Queue (background jobs)
- Cable: Solid Cable (WebSocket connections)

### Server Configuration

**Thruster**: HTTP asset caching/compression and X-Sendfile acceleration
- Default CMD: `./bin/thrust ./bin/rails server`
- Port: 80 (container), mapped via Kamal proxy

**Puma**:
- Threads: `RAILS_MAX_THREADS` (default: 3)
- Port: `PORT` env var (default: 3000)
- PID file: Optional via `PIDFILE` env var

---

## Current Gaps & Risks

### 1. Custom Domains Support

**Current State**:
- ✅ Hostname-based resolution works for single hostname per tenant
- ❌ **No custom domain support** - tenants can only use one hostname
- ❌ **No domain mapping model** - no way to map multiple domains to one tenant
- ❌ **No DNS validation** - no verification that custom domains point to the app

**Risks**:
- Cannot support multiple domains per tenant (e.g., `example.com` and `www.example.com`)
- Cannot support custom domains for tenants (e.g., tenant wants to use their own domain)
- No wildcard domain support
- TenantResolver only handles single hostname per tenant

**Proposed Solution**:
1. Create `Domain` model (belongs_to :tenant, hostname: string, verified: boolean, verified_at: datetime)
2. Update `TenantResolver` to check `domains` table after primary hostname lookup
3. Add DNS verification job (check for CNAME or A record pointing to app)
4. Add admin interface to manage custom domains
5. Support wildcard domains in resolver (e.g., `*.example.com` → tenant)

### 2. Scheduled Content Ingestion

**Current State**:
- ✅ Solid Queue recurring jobs infrastructure exists
- ✅ `config/recurring.yml` configured for recurring tasks
- ❌ **No Source model** - no way to define content sources
- ❌ **No ingestion jobs** - no jobs to fetch content
- ❌ **No scheduling per tenant** - no tenant-specific ingestion schedules

**Risks**:
- No automated content fetching (relies on manual admin input)
- No way to schedule periodic content updates
- No tenant-specific ingestion configuration
- No rate limiting for external API calls

**Proposed Solution**:
1. Create `Source` model (tenant_id, kind: enum, name, config: jsonb, schedule: jsonb, enabled: boolean, last_run_at, last_status)
2. Implement ingestion jobs:
   - `FetchSerpApiNewsJob` - Google News via SerpAPI
   - `FetchRssJob` - RSS/Atom feeds (Feedjira gem already included)
   - `UpsertListingsJob` - Normalize and dedupe discovered URLs
3. Create `SourceSchedulerJob` - runs periodically, enqueues source-specific jobs based on schedule
4. Use Solid Queue recurring tasks for per-source scheduling with jitter
5. Add rate limiting and retry logic with exponential backoff
6. Add source management admin interface

### 3. Infrastructure for Dokku/DigitalOcean VPS

**Current State**:
- ✅ Dockerfile exists (compatible with Dokku)
- ✅ Procfile.dev exists (development only)
- ❌ **No Procfile** - Dokku requires Procfile for process definition
- ❌ **No Dokku-specific config** - no app.json or nginx configuration
- ❌ **Single-server assumptions** - designed for Kamal, needs adjustment for Dokku

**Risks**:
- Kamal deployment config won't work on Dokku without modification
- No Procfile means Dokku can't determine process types
- Database connection pooling may need adjustment for Dokku
- SSL certificate management differs (Dokku uses Let's Encrypt plugin)

**Proposed Solution**:
1. Create `Procfile` with web and worker processes:
   ```
   web: bundle exec puma -C config/puma.rb
   worker: bundle exec rails solid_queue:start
   ```
2. Update `config/database.yml` to use `DATABASE_URL` (Dokku standard)
3. Document Dokku deployment process (app creation, database provisioning, SSL)
4. Consider Dokku-specific environment variables for multi-database setup
5. Add `app.json` for Dokku app configuration (optional but helpful)

---

## Proposed Direction

### Phase 1: Custom Domains (High Priority)

1. **Model & Migration**:
   ```ruby
   # Migration: Create domains table
   create_table :domains do |t|
     t.references :tenant, null: false, foreign_key: true
     t.string :hostname, null: false
     t.boolean :verified, default: false
     t.datetime :verified_at
     t.timestamps
   end
   add_index :domains, :hostname, unique: true
   ```

2. **Update TenantResolver**:
   - Try primary hostname lookup first
   - Fallback to `Domain` lookup if not found
   - Return 404 if domain exists but not verified

3. **DNS Verification**:
   - Background job: `VerifyDomainJob`
   - Check DNS records (A, CNAME) point to app
   - Update `verified_at` on success

4. **Admin Interface**:
   - Add domain management to admin panel
   - Show verification status
   - Manual verification trigger

### Phase 2: Scheduled Ingestion (High Priority)

1. **Source Model**:
   ```ruby
   # Migration: Create sources table
   create_table :sources do |t|
     t.references :tenant, null: false, foreign_key: true
     t.integer :kind, null: false  # enum: serp_api_google_news, rss, api, web_scraper
     t.string :name, null: false
     t.jsonb :config, default: {}, null: false
     t.jsonb :schedule, default: {}, null: false
     t.boolean :enabled, default: true
     t.datetime :last_run_at
     t.string :last_status
     t.timestamps
   end
   add_index :sources, [:tenant_id, :name], unique: true
   ```

2. **Ingestion Jobs**:
   - `FetchSerpApiNewsJob` - accepts source_id, calls SerpAPI
   - `FetchRssJob` - accepts source_id, parses feed
   - `UpsertListingsJob` - accepts source_id, raw_items array, normalizes URLs
   - `SourceSchedulerJob` - runs every 5 minutes, checks enabled sources, enqueues fetch jobs

3. **Recurring Tasks**:
   - Add per-source recurring tasks via Solid Queue recurring API
   - Support cron expressions in `schedule` JSONB field
   - Add jitter to prevent thundering herd

4. **Admin Interface**:
   - Source CRUD in admin panel
   - Test source button (manual run)
   - Source execution history

### Phase 3: Dokku Deployment (Medium Priority)

1. **Procfile**:
   ```procfile
   web: bundle exec puma -C config/puma.rb
   worker: bundle exec rails solid_queue:start
   ```

2. **Database Configuration**:
   - Update `config/database.yml` to use `DATABASE_URL` in production
   - Handle multi-database setup via environment variables

3. **Documentation**:
   - Dokku deployment guide
   - Environment variable setup
   - SSL certificate configuration
   - Database backup procedures

4. **Optional Enhancements**:
   - `app.json` for Dokku app metadata
   - Health check endpoint (`/up`) already exists
   - Log aggregation setup (optional)

---

## Testing

### Current Test Coverage

**Existing Specs**:
- ✅ `spec/middleware/tenant_resolver_spec.rb` - Comprehensive middleware tests
- ✅ `spec/models/concerns/tenant_scoped_spec.rb` - Tenant scoping tests
- ✅ `test/middleware/tenant_resolver_test.rb` - Additional middleware tests
- ✅ `test/integration/tenant_resolution_test.rb` - Integration tests

### Recommended Additional Test

**Request Spec for Tenant Resolution** (Lightweight proof):
- Test actual HTTP request through full stack
- Verify `Current.tenant` is set correctly in controllers
- Verify tenant-scoped data isolation in practice

---

## Summary

**Current Strengths**:
- ✅ Solid multi-tenancy foundation with row-level scoping
- ✅ Hostname-based tenant resolution working well
- ✅ Modern job system (Solid Queue) integrated
- ✅ Containerization ready (Docker + Kamal)

**Immediate Gaps**:
- ❌ No custom domain support
- ❌ No scheduled content ingestion
- ❌ Dokku deployment needs configuration

**Next Steps**:
1. Implement custom domains (Domain model + TenantResolver update)
2. Implement scheduled ingestion (Source model + jobs)
3. Add Dokku deployment configuration (Procfile + docs)

---

*Last Updated: 2025-01-20*