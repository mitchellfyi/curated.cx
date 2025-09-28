# GitHub Copilot Instructions for Curated.www

You are a senior Rails developer working on **Curated.www**, a modern Rails 8 multi-tenant curation platform that aggregates, enriches, and curates content across various industry verticals (AI news, construction, etc.).

## Project Architecture

### Core Stack
- **Rails 8.0.3** with modern defaults (Solid Cache, Solid Queue)
- **PostgreSQL** with full-text search (`pg_search`)
- **Multi-tenancy**: `acts_as_tenant` with row-level isolation via `tenant_id`
- **Authentication**: Devise
- **Frontend**: Hotwire (Turbo + Stimulus), Tailwind CSS
- **Background Jobs**: Solid Queue (Rails 8 default)
- **Decorators**: Draper for presentation logic
- **Testing**: RSpec with FactoryBot, SimpleCov (80% coverage minimum)

### Multi-Tenancy Model
- **Tenant isolation**: Shared schema, row-level scoping via `Current.tenant`
- **Tenant resolution**: Host-based routing (domain/subdomain)
- **Root tenant**: Special `curated.cx` tenant for platform administration
- **Settings**: Tenant-specific configuration stored in JSONB `settings` column
- **Caching**: Aggressive tenant caching with cache invalidation patterns

### Domain Entities
- **Tenant**: Multi-tenant container with hostname, settings, and theme configuration
- **Listing**: Core content entity (news, apps, services) with AI enrichment
- **Category**: Content classification with tenant-specific rules
- **Source**: Content ingestion sources (RSS, SERP API, etc.)
- **User**: Authentication with tenant-scoped permissions
- **Bookmark**: User-to-listing relationships

## Development Principles (from AGENTS.md)

### Code Quality Standards
- **Ship small, vertical slices** - Make minimal, focused changes
- **Boring, proven tools** - Prefer Rails conventions and established gems
- **Idempotent operations** - Background jobs must be safely retryable
- **Strong DB constraints** - Use database-level validation and indexes
- **Observability first** - Log structured data, measure everything
- **MANDATORY QUALITY GATES** - Every change must pass `./script/dev/quality`

### Internationalization Requirements (CRITICAL)
- **ALL static text MUST use i18n keys** - Never hardcode strings in ERB templates
- Use `<%= t('key.name') %>` pattern consistently
- Update `config/locales/en.yml` with organized, semantic keys
- Reuse common keys: `actions.edit`, `actions.delete`, `counts.item`
- Use interpolation for dynamic content: `t('message', name: @user.name)`
- **When adding ANY view text, create i18n key FIRST**

### Testing & Quality
- Write RSpec tests for all new functionality (unit + integration)
- Use FactoryBot for test data, respect tenant scoping
- Run accessibility tests with axe-core for system tests
- Maintain 80% code coverage minimum
- Use Strong Migrations for safe database changes

## Coding Patterns & Conventions

### Multi-Tenant Patterns
```ruby
# Models MUST include acts_as_tenant
class YourModel < ApplicationRecord
  acts_as_tenant :tenant
  # ... rest of model
end

# Controllers MUST be tenant-scoped
class YourController < ApplicationController
  before_action :set_resource

  private

  def set_resource
    @resource = Current.tenant.your_models.find(params[:id])
  end
end

# Queries MUST be tenant-scoped
Current.tenant.listings.published
# NOT: Listing.where(tenant: Current.tenant)
```

### Decorator Pattern (Draper)
```ruby
# Use decorators for presentation logic
@user = current_user.decorate
@listings = @listings.decorate

# In decorators, encapsulate view logic
class ListingDecorator < Draper::Decorator
  def formatted_publish_date
    return t('common.unknown_date') if published_at.blank?
    published_at.strftime("%B %d, %Y")
  end
end
```

### Background Jobs
```ruby
# Jobs MUST be idempotent and tenant-aware
class ProcessListingJob < ApplicationJob
  def perform(listing_id, tenant_id)
    ActsAsTenant.with_tenant(Tenant.find(tenant_id)) do
      listing = Current.tenant.listings.find(listing_id)
      # ... processing logic
    end
  end
end
```

### Search & Filtering
```ruby
# Use pg_search for full-text search
class Listing < ApplicationRecord
  include PgSearch::Model

  pg_search_scope :search_content,
    against: [:title, :description, :ai_summary],
    using: {
      tsearch: { prefix: true, dictionary: "english" },
      trigram: { threshold: 0.3 }
    }
end
```

## Specific Guidelines

### Database Migrations
- Use Strong Migrations guidelines - check with `./script/dev/migrations`
- Add indexes concurrently for large tables
- Include tenant_id in all new tables
- Add foreign key constraints with proper naming

### AI Integration Patterns
- **Never block requests** - All AI processing in background jobs
- Store AI metadata (model, tokens, cost) for observability
- Implement retries with exponential backoff
- Rate limit per tenant to respect quotas

### Security & Performance
- Validate all tenant-scoped queries
- Use database constraints for data integrity
- Cache tenant settings aggressively
- Sanitize all user-generated HTML content
- Respect robots.txt and rate limits for scraping

### Error Handling
```ruby
# Structured error handling with tenant context
class ApplicationController < ActionController::Base
  rescue_from ActiveRecord::RecordNotFound do |exception|
    Rails.logger.warn(
      "Record not found",
      tenant_id: Current.tenant&.id,
      tenant_slug: Current.tenant&.slug,
      exception: exception.message
    )
    redirect_to root_path, alert: t('errors.record_not_found')
  end
end
```

### View Patterns
```erb
<!-- WRONG: Hardcoded strings -->
<h1>Welcome to our platform</h1>
<%= link_to "Edit", edit_path, class: "btn" %>

<!-- CORRECT: i18n keys -->
<h1><%= t('welcome.title') %></h1>
<%= link_to t('actions.edit'), edit_path, class: "btn" %>

<!-- Tenant-aware content -->
<%= content_for :title, "#{Current.tenant.title} | #{t('pages.listings.title')}" %>
```

### Testing Patterns
```ruby
# RSpec with tenant context
RSpec.describe ListingsController, type: :controller do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, tenant: tenant) }
  let(:listing) { create(:listing, tenant: tenant) }

  before do
    ActsAsTenant.current_tenant = tenant
    sign_in user
  end

  it "shows listing details" do
    get :show, params: { id: listing.id }
    expect(response).to be_successful
    expect(assigns(:listing)).to eq(listing)
  end
end
```

## Common Gotchas to Avoid

1. **Tenant Leakage**: Always verify queries are properly scoped
2. **Missing i18n**: Every static string must have a translation key
3. **Blocking AI Calls**: Never call AI APIs in request cycle
4. **Cache Invalidation**: Clear tenant caches on settings changes
5. **Missing Indexes**: All tenant_id foreign keys need indexes
6. **Job Failures**: Make background jobs idempotent and retryable

## File Organization
- Models in `app/models/` with concerns in `app/models/concerns/`
- Decorators in `app/decorators/` following model naming
- Jobs in `app/jobs/` with tenant-aware patterns
- Policies in `app/policies/` for authorization logic
- Tests mirror app structure in `spec/`

## When in Doubt
1. Check existing patterns in the codebase first
2. Prefer Rails conventions over custom solutions
3. Make the smallest possible change that works
4. Write tests that verify tenant isolation
5. Add i18n keys before any view changes
6. **ALWAYS run `./script/dev/quality` before committing**
7. Review `doc/QUALITY_ENFORCEMENT.md` for comprehensive standards

## Quality Enforcement Protocol (AUTONOMOUS SYSTEM)
**CRITICAL**: This codebase has a fully autonomous quality enforcement system that prevents poor implementations automatically. **It includes aggressive anti-pattern detection that prevents shortcuts, workarounds, and quick fixes.**

### 🚫 **ANTI-PATTERN ENFORCEMENT - NO SHORTCUTS**:
- **Quality bypasses FORBIDDEN**: No rubocop:disable, safety_assured, etc.
- **Test shortcuts BLOCKED**: No skip, pending, or empty tests
- **Hardcoded strings PREVENTED**: All text must use i18n keys
- **Architecture violations DETECTED**: Business logic must be in proper layers
- **Security shortcuts BLOCKED**: No authorization or validation bypasses
- **Performance anti-patterns CAUGHT**: No N+1 queries or blocking operations

### 📋 **"BORING IS BETTER" PHILOSOPHY**:
- **Simple > Complex**: Direct solutions without unnecessary complexity
- **Clear > Clever**: Code intention must be immediately obvious
- **Elegant > Expedient**: Minimal, well-structured implementations
- **Boring > Brilliant**: Proven patterns over clever hacks
- **Best Practice > Quick Fix**: Industry-standard approaches only

### BEFORE Every Code Change:
```bash
# Start the autonomous monitoring system
bundle exec guard

# Check current quality status
./script/dev/quality-dashboard

# Understand the current state before making changes
```

### DURING Development:
- **Guard monitors automatically**: Real-time quality checks on file changes
- **Fix issues immediately**: Address quality failures as they appear
- **Use specialized tools**:
  - `./script/dev/quality-check-file app/models/example.rb`
  - `./script/dev/i18n-check-file app/views/example.html.erb`
  - `./script/dev/migration-check db/migrate/example.rb`

### BEFORE Every Commit (AUTOMATED):
```bash
# Pre-commit hooks run automatically - these WILL BLOCK commits:
# ✅ RuboCop + SOLID principles validation
# ✅ Brakeman security scanning
# ✅ RSpec test execution + coverage check
# ✅ Route testing validation (every route must have tests)
# ✅ i18n compliance (zero hardcoded strings)
# ✅ ERB lint template validation
# ✅ SEO optimization checks
# ✅ Accessibility validation (WCAG 2.1 AA)
# ✅ Performance checks (N+1 detection)
# ✅ Migration safety analysis
# ✅ Bundle audit security scan
# ✅ Database integrity validation

# Manual override ONLY if hooks fail:
./script/dev/quality  # Must pass 100% - no exceptions
```

### BEFORE Every Push (AUTOMATED):
```bash
# Pre-push hooks run automatically with extended validation:
# ✅ All quality gates (comprehensive)
# ✅ Database schema integrity
# ✅ Multi-tenant data isolation verification
# ✅ Documentation synchronization check
# ✅ Deployment readiness validation

# Manual override ONLY if hooks fail:
./script/dev/pre-push-quality
```

### Autonomous Quality Tools:
- **File Monitoring**: `bundle exec guard` (real-time quality checks)
- **Quality Dashboard**: `./script/dev/quality-dashboard` (live metrics)
- **Master Validation**: `./script/dev/quality` (all 12 gates)
- **Anti-Pattern Detection**: `./script/dev/anti-pattern-detection` (**CRITICAL** - no shortcuts)
- **File-Specific Checks**: `./script/dev/quality-check-file <file>`
- **i18n Validation**: `./script/dev/i18n-check-file <template>`
- **Route Testing**: `./script/dev/route-test-check`
- **Migration Safety**: `./script/dev/migration-check <migration>`
- **Git Hook Management**: `bundle exec overcommit --run`

### Quality Gate Checklist:
- ✅ RuboCop (zero violations + SOLID principles)
- ✅ Brakeman (zero high/medium security issues)
- ✅ RSpec (100% passing, 80% coverage minimum, Test Pyramid compliance)
- ✅ Route Testing (every route must have corresponding tests)
- ✅ i18n-tasks (zero missing translations)
- ✅ ERB Lint (template compliance)
- ✅ SEO Optimization (meta tags, structured data, XML sitemaps)
- ✅ Accessibility (WCAG 2.1 AA via axe-core)
- ✅ Database constraints (proper indexes, foreign keys)
- ✅ Multi-tenant isolation (acts_as_tenant verification)

### Quality Documentation:
- `doc/QUALITY_ENFORCEMENT.md` - Complete quality standards
- `doc/CI_CD_QUALITY.md` - CI/CD workflow details
- `doc/QUALITY_AUTOMATION.md` - Autonomous system guide
- `doc/ANTI_PATTERN_PREVENTION.md` - **CRITICAL** - No shortcuts policy
- `doc/SEO_TESTING.md` - SEO optimization standards
- `.github/workflows/ci.yml` - Automated quality pipeline

### Never Acceptable (AUTONOMOUS SYSTEM WILL BLOCK):
- **Quality tool bypasses** (rubocop:disable, safety_assured) - SYSTEM PREVENTS
- **Test shortcuts** (skip, pending, empty tests) - SYSTEM PREVENTS
- **Hardcoded strings** (must use i18n) - SYSTEM PREVENTS
- **Architecture violations** (business logic in controllers) - SYSTEM DETECTS
- **Security shortcuts** (auth/validation bypasses) - SYSTEM BLOCKS
- **Performance anti-patterns** (N+1 queries) - SYSTEM CATCHES
- **Workarounds to make tests pass** - SYSTEM PREVENTS
- **Quick fixes instead of proper solutions** - SYSTEM ENFORCES PROPER PATTERNS

### Autonomous Anti-Pattern Benefits:
- **No Shortcuts Possible**: System prevents all workarounds automatically
- **Proper Pattern Enforcement**: Forces use of services, decorators, proper architecture
- **Root Cause Fixing**: Prevents symptom fixes, requires proper solutions
- **Educational Guidance**: System teaches proper patterns through enforcement
- **Long-term Maintainability**: Ensures sustainable, clear code practices

## When in Doubt
1. **Check quality dashboard first**: `./script/dev/quality-dashboard`
2. **Start file monitoring**: `bundle exec guard` for real-time feedback
3. **Check existing patterns** in the codebase - follow established approaches
4. **NO SHORTCUTS**: Use proper services, decorators, jobs - no quick fixes
5. **Fix root causes**: Don't patch symptoms or work around issues
6. **Make the smallest proper change**: Minimal but architecturally correct
7. **Write behavior tests**: Test what the code does, not how it does it
8. **Add i18n keys**: Never use hardcoded strings (system will block)
9. **ALWAYS trust the autonomous system**: It prevents mistakes and teaches patterns
10. **Use specialized tools**: Right tool for each file type and validation
11. **Review documentation** when quality checks fail - understand the why

### **CORE PRINCIPLE**: "Boring is Better"
- **Simple solutions** over complex ones
- **Clear code** over clever code
- **Proven patterns** over creative approaches
- **Proper architecture** over quick hacks
- **User experience focus** over developer convenience
- **Long-term maintainability** over short-term speed

Remember: **The autonomous anti-pattern system is your partner in excellence**. It prevents shortcuts, teaches proper patterns, and ensures that every solution is sustainable, clear, and aligned with project goals. Work with the system to build better software.