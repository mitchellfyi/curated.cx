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

## Resolved Gaps (Previously Identified)

### 1. Custom Domains Support ✅ RESOLVED

**Implementation** (completed 2025-01):
- ✅ `Domain` model with hostname, primary flag, verified status
- ✅ `Site` model with multiple domains per site
- ✅ `TenantResolver` middleware with multi-strategy resolution
- ✅ DNS verification service (A, CNAME record checking)
- ✅ Admin interface for domain management
- ✅ www variant handling (automatic fallback)
- ✅ Subdomain pattern support (configurable per site)

See `docs/domain-routing.md` for complete domain resolution documentation.
See `docs/DATA_MODEL.md` for Tenant → Site → Domain hierarchy.

### 2. Scheduled Content Ingestion ✅ RESOLVED

**Implementation** (completed 2025-01):
- ✅ `Source` model with kind enum (serp_api_google_news, rss, api, web_scraper)
- ✅ `ImportRun` model for batch execution tracking
- ✅ `ContentItem` model for normalized content storage
- ✅ URL canonicalisation and deduplication
- ✅ Solid Queue recurring tasks via `config/recurring.yml`
- ✅ Rate limiting and retry logic
- ✅ Admin interface for source management

See `docs/ingestion-model.md` for ingestion system documentation.
See `docs/background-jobs.md` for job configuration.

### 3. Infrastructure for Dokku ✅ RESOLVED

**Implementation** (completed 2025-01):
- ✅ `Procfile` with web process
- ✅ Database configuration using `DATABASE_URL`
- ✅ Multi-database setup (primary, cache, queue, cable)
- ✅ Dokku deployment documentation
- ✅ Let's Encrypt SSL via dokku-letsencrypt plugin
- ✅ Domain sync script for automated domain management
- ✅ Production deployment working at curated.cx

See `docs/deploy-dokku.md` for complete deployment guide.

---

## Future Enhancements

### Potential Improvements

1. **Personalized Feeds**:
   - User reading history tracking
   - Topic preference learning
   - Source preference management

2. **Advanced Analytics**:
   - Detailed engagement metrics dashboard
   - A/B testing framework
   - Click-through rate optimization

3. **API & Integrations**:
   - Public API for content access
   - Webhook notifications for new content
   - Third-party integrations (Slack, Discord)

4. **Multi-Region Support**:
   - CDN integration for static assets
   - Database read replicas
   - Geographic content filtering

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
- ✅ Site/Domain hierarchy for flexible domain management
- ✅ Hostname-based resolution with multiple fallback strategies
- ✅ Modern job system (Solid Queue) with recurring tasks
- ✅ Content ingestion pipeline (Source → ImportRun → ContentItem)
- ✅ AI editorialisation for content enhancement
- ✅ Community features (voting, comments, flagging, moderation)
- ✅ Monetisation support (affiliate tracking, featured placements)
- ✅ Production deployment on Dokku with SSL

**Deployed Sites**:
- curated.cx (root hub)
- ainews.cx (AI News)
- construction.cx (Construction News)
- dayz.cx (DayZ Community Hub)

---

*Last Updated: 2025-01-25*