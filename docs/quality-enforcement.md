# Quality Enforcement Standards for Curated.www

## Overview

This document defines the comprehensive quality enforcement standards that must be adhered to for ALL changes to the Curated.www codebase. These standards are designed to maintain code quality, security, performance, accessibility, and maintainability.

**Zero tolerance policy**: No exceptions, no workarounds, no "temporary" bypasses.

## Quality Gates Architecture

### Level 1: Pre-commit Checks (Local Development)
Every developer MUST run these before committing:

```bash
./script/dev/quality
```

This comprehensive script runs all quality checks and must pass 100%.

### Level 2: CI/CD Pipeline
Automated checks run on every push and pull request via GitHub Actions (`.github/workflows/ci.yml`).

### Level 3: Pre-deployment Verification
Additional production-readiness checks before deployment.

## Detailed Quality Standards

### 1. Code Style & Conventions (RuboCop Rails Omakase)

**Tool**: `bundle exec rubocop`
**Standard**: Rails Omakase configuration with zero violations
**Rationale**: Consistent code style improves readability and maintainability

#### Requirements:
- Zero RuboCop violations across entire codebase
- Follow Rails conventions and idioms
- Consistent method naming, indentation, line length
- Proper use of Ruby idioms and patterns
- **SOLID Principles enforcement**: Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, Dependency Inversion

#### SOLID Principles Implementation:
```ruby
# Single Responsibility - Each class has one reason to change
class ListingSearchService
  def initialize(tenant, params)
    @tenant = tenant
    @params = params
  end

  def call
    listings = @tenant.listings
    listings = apply_search(listings) if @params[:q].present?
    listings = apply_filters(listings)
    listings
  end
end

# Open/Closed - Open for extension, closed for modification
class NotificationDeliveryService
  def deliver(notification)
    delivery_method_for(notification.type).deliver(notification)
  end

  private

  def delivery_method_for(type)
    case type
    when 'email' then EmailDelivery.new
    when 'sms' then SmsDelivery.new
    else raise UnsupportedDeliveryType
    end
  end
end
```

#### Configuration:
- Primary config: `.rubocop.yml` (inherits from rails-omakase)
- Custom overrides documented in config file
- Auto-correct safe violations: `bundle exec rubocop -A`

#### Enforcement:
- Local: Must pass before commit
- CI: Blocks merge if violations found
- Pre-deployment: Included in deployment checks

### 2. Security Analysis (Brakeman)

**Tool**: `bundle exec brakeman`
**Standard**: Zero high/medium security vulnerabilities
**Rationale**: Prevent security vulnerabilities from reaching production

#### Requirements:
- Zero high-severity security issues
- Zero medium-severity security issues
- Low-severity issues reviewed and documented if accepted
- All CVE vulnerabilities addressed

#### What Brakeman Checks:
- SQL injection vulnerabilities
- Cross-site scripting (XSS)
- Cross-site request forgery (CSRF)
- Command injection
- File access vulnerabilities
- Dangerous redirects
- Mass assignment vulnerabilities

#### Configuration:
- Config file: `config/brakeman.ignore` (for documented exceptions)
- Output format: JSON for CI integration
- All exceptions must be documented with rationale

### 3. Test Coverage & Quality (RSpec)

**Tools**: `bundle exec rspec`, SimpleCov
**Standards**:
- 100% test passage rate
- 80% minimum code coverage
- All critical paths tested

#### Test Pyramid Structure:
1. **Unit Tests (70%)**:
   - Models: validations, associations, scopes, methods
   - Services: business logic, edge cases
   - Helpers: presentation logic
   - Decorators: display formatting
   - Jobs: background processing logic

2. **Integration Tests (20%)**:
   - Controller specs: request/response cycles
   - Request specs: API endpoints
   - **Route specs: All routes must be tested**
   - Policy specs: authorization logic
   - Mailer specs: email functionality

3. **System Tests (10%)**:
   - End-to-end user workflows
   - Multi-tenant functionality
   - JavaScript interactions (Stimulus)
   - Accessibility compliance

#### Coverage Requirements:
- Overall: 80% minimum (configured in `spec/spec_helper.rb`)
- Models: 90% minimum
- Controllers: 80% minimum
- Services: 95% minimum
- Critical business logic: 100%

#### Test Quality Standards:
- Fast execution (< 30 seconds for full suite)
- Deterministic (no flaky tests)
- Isolated (no test interdependencies)
- Descriptive test names and documentation
- Proper factory usage (FactoryBot)
- Database cleaning between tests
- **Route Coverage: Every route must have corresponding tests**

#### Route Testing Requirements:
```ruby
# spec/routing/listings_routing_spec.rb
RSpec.describe "Listings routing", type: :routing do
  it "routes to listings index" do
    expect(get: "/listings").to route_to("listings#index")
  end

  it "routes to listing show" do
    expect(get: "/listings/1").to route_to("listings#show", id: "1")
  end

  # Test all defined routes
end
```

### 4. Internationalization (i18n-tasks)

**Tool**: `bundle exec i18n-tasks`
**Standard**: Zero missing translations, zero hardcoded strings in views
**Rationale**: Application must be fully localizable

#### Requirements:
- All static text uses i18n keys: `<%= t('key.name') %>`
- No hardcoded strings in ERB templates
- All i18n keys have English translations
- Translation keys follow semantic naming
- Unused translations are cleaned up

#### Key Organization:
```yaml
# config/locales/en.yml
en:
  actions:
    edit: "Edit"
    delete: "Delete"
    save: "Save"
  pages:
    listings:
      title: "Latest News"
      empty: "No listings found"
  models:
    listing:
      title: "Article"
      attributes:
        title: "Title"
```

#### Checks Performed:
- Missing translations: `i18n-tasks missing`
- Unused translations: `i18n-tasks unused`
- Consistency checks: `i18n-tasks health`
- Normalization: `i18n-tasks normalize`

### 5. Template Quality (ERB Lint)

**Tool**: `bundle exec erb_lint`
**Standard**: Clean, semantic HTML templates
**Configuration**: `.erb_lint.yml`

#### Requirements:
- Proper HTML structure and semantics
- Consistent indentation and formatting
- No trailing whitespace
- Proper closing tags
- Accessibility-friendly markup

### 6. Accessibility Compliance (axe-core)

**Tools**: `axe-rspec`, `axe-capybara`
**Standard**: WCAG 2.1 AA compliance
**Rationale**: Ensure application is accessible to all users

#### System Test Coverage:
- All major user workflows tested with axe-core
- Form interactions and validation
- Navigation and keyboard accessibility
- Color contrast and text alternatives

#### WCAG 2.1 AA Requirements:
- **Perceivable**: Alt text, captions, color contrast
- **Operable**: Keyboard navigation, no seizure triggers
- **Understandable**: Clear language, predictable interface
- **Robust**: Valid HTML, assistive technology compatibility

#### Implementation:
```ruby
# In system specs
it "meets accessibility standards", :accessibility do
  visit root_path
  expect(page).to be_axe_clean
end
```

#### Manual Testing Requirements:
- Keyboard-only navigation
- Screen reader compatibility (VoiceOver/NVDA)
- High contrast mode support
- 200% zoom level support

### 7. SEO Optimization & Meta Tags

**Tools**: Meta Tags gem, HTML validation, structured data
**Standard**: Complete SEO optimization for all public pages
**Rationale**: Ensure discoverability and proper search engine indexing

#### SEO Requirements:
- **Meta Tags**: Title, description, canonical URLs for all pages
- **Open Graph**: Social media sharing optimization
- **Twitter Cards**: Rich Twitter preview support
- **Structured Data**: JSON-LD schema markup
- **XML Sitemaps**: Auto-generated for all tenant content
- **Robots.txt**: Proper crawler guidance
- **Canonical URLs**: Prevent duplicate content issues

#### Meta Tags Implementation:
```ruby
# In controllers
def show
  @listing = Current.tenant.listings.find(params[:id]).decorate

  set_meta_tags(
    title: @listing.seo_title,
    description: @listing.seo_description,
    canonical: listing_url(@listing),
    og: {
      title: @listing.title,
      description: @listing.description,
      image: @listing.image_url,
      url: listing_url(@listing),
      type: 'article'
    },
    twitter: {
      card: 'summary_large_image',
      title: @listing.title,
      description: @listing.description,
      image: @listing.image_url
    }
  )
end

# In decorators
class ListingDecorator < Draper::Decorator
  def seo_title
    "#{object.title} | #{Current.tenant.title}"
  end

  def seo_description
    object.ai_summaries&.dig('short') || object.description&.truncate(160)
  end
end
```

#### Structured Data (JSON-LD):
```ruby
# In views
<%= structured_data do
  {
    "@context": "https://schema.org",
    "@type": "Article",
    "headline": @listing.title,
    "description": @listing.description,
    "image": @listing.image_url,
    "datePublished": @listing.published_at&.iso8601,
    "author": {
      "@type": "Organization",
      "name": Current.tenant.title
    },
    "publisher": {
      "@type": "Organization",
      "name": Current.tenant.title,
      "logo": {
        "@type": "ImageObject",
        "url": Current.tenant.logo_url
      }
    }
  }
end %>
```

#### XML Sitemap Generation:
```ruby
# config/routes.rb
get '/sitemap.xml', to: 'sitemaps#show', format: :xml, as: :sitemap

# app/controllers/sitemaps_controller.rb
class SitemapsController < ApplicationController
  def show
    @listings = Current.tenant.listings.published.includes(:category)
    respond_to do |format|
      format.xml { render layout: false }
    end
  end
end
```

#### SEO Testing:
```ruby
# spec/system/seo_spec.rb
RSpec.describe "SEO optimization", type: :system do
  let(:listing) { create(:listing, :published) }

  it "includes proper meta tags" do
    visit listing_path(listing)

    expect(page).to have_title(listing.decorate.seo_title)
    expect(page).to have_meta_description(listing.decorate.seo_description)
    expect(page).to have_meta_property('og:title', content: listing.title)
    expect(page).to have_meta_property('og:description', content: listing.description)
    expect(page).to have_link(rel: 'canonical', href: listing_url(listing))
  end

  it "includes structured data" do
    visit listing_path(listing)

    structured_data = find('script[type="application/ld+json"]', visible: false)
    data = JSON.parse(structured_data.text(:all))

    expect(data['@type']).to eq('Article')
    expect(data['headline']).to eq(listing.title)
  end
end
```

### 7. Performance Standards

**Tools**: Bullet, Prosopite, RSpec Performance
**Standards**: No N+1 queries, response times under thresholds
**Configuration**: Development gems for query detection

#### Database Performance:
- Zero N+1 queries (detected by Bullet/Prosopite)
- Proper database indexes on foreign keys
- Query optimization for large datasets
- Database constraints for data integrity

#### Response Time Thresholds:
- Page loads: < 200ms (without network)
- API endpoints: < 100ms
- Background jobs: Appropriate timeout handling
- Database queries: Individual queries < 50ms

#### Performance Testing:
```ruby
# spec/performance/listings_spec.rb
RSpec.describe "Listings performance" do
  it "loads index page efficiently" do
    expect { get listings_path }.to perform_under(200).ms
  end
end
```

### 8. Database Migration Safety (Strong Migrations)

**Tool**: Strong Migrations gem
**Standard**: All migrations reviewed and safe for production
**Script**: `./script/dev/migrations`

#### Safe Migration Practices:
- Add columns without defaults first, then backfill
- Create indexes concurrently on large tables
- Use multi-step approach for destructive changes
- Test migrations on production-sized datasets

#### Migration Checklist:
- [ ] No lock-inducing operations during peak hours
- [ ] Proper rollback strategy documented
- [ ] Data backfill jobs are idempotent
- [ ] Foreign key constraints properly named
- [ ] Indexes added for query patterns

### 9. Dependency Security (Bundle Audit)

**Tool**: `bundle exec bundle-audit`
**Standard**: Zero known security vulnerabilities
**Frequency**: Checked on every dependency update

#### Requirements:
- All gems updated to secure versions
- Known CVEs addressed immediately
- Security advisories reviewed and acted upon
- Dependency updates tested thoroughly

### 10. Database Integrity

**Standards**: Proper schema design and constraints
**Tools**: Database schema validation

#### Requirements:
- All foreign keys have proper constraints
- Unique constraints where needed
- Check constraints for data validation
- Proper indexing strategy
- Multi-tenancy isolation enforced at DB level

#### Tenant Isolation Checks:
```ruby
# Every tenant-scoped model must have:
acts_as_tenant :tenant
validates :tenant, presence: true

# Database constraints:
# - tenant_id NOT NULL on all tenant-scoped tables
# - Proper foreign key constraints
# - Unique indexes include tenant_id where relevant
```

## Quality Tool Scripts

### Primary Quality Script: `./script/dev/quality`

This script runs all quality checks in the correct order:

1. RuboCop (code style)
2. Brakeman (security)
3. RSpec (tests and coverage)
4. ERB Lint (template quality)
5. i18n-tasks (internationalization)
6. Bundle Audit (dependency security)
7. Accessibility tests
8. Performance tests

### Individual Tool Scripts:

```bash
# Individual checks
./script/dev/accessibility  # Accessibility-focused tests and guidance
./script/dev/i18n          # i18n health and missing translations
./script/dev/migrations     # Migration safety analysis
```

## Failure Response Protocol

### When Quality Checks Fail:

1. **STOP immediately** - No further development until fixed
2. **Identify root cause** - Don't just fix symptoms
3. **Understand the rationale** - Why does this check exist?
4. **Fix the underlying issue** - Don't work around the check
5. **Re-run ALL quality checks** - Ensure no regression
6. **Document any exceptions** - If a check is genuinely irrelevant

### Never Acceptable:
- Disabling quality checks "temporarily"
- Working around tool limitations instead of fixing
- Committing with failing tests
- Ignoring security warnings
- Skipping accessibility requirements
- Using hardcoded strings in templates

## CI/CD Integration

See [ci-cd-quality.md](ci-cd-quality.md) for detailed CI/CD workflow documentation.

### Quality Gates in CI:
- **Fast Feedback**: Lint, format, basic security
- **Comprehensive Testing**: Full test suite with coverage
- **Deep Analysis**: Code quality, complexity, dependencies
- **Build Verification**: Production build validation

### Merge Requirements:
- All CI checks must pass (green)
- Code review approval required
- Branch up to date with main
- No merge conflicts

## Monitoring and Maintenance

### Weekly Quality Review:
- Review failed CI builds and patterns
- Update quality tool configurations
- Address technical debt identified by tools
- Update this documentation as tools evolve

### Monthly Quality Metrics:
- Code coverage trends
- Security vulnerability discovery/resolution time
- Accessibility compliance coverage
- Performance regression analysis

### Quality Tool Updates:
- Keep all quality tools updated to latest versions
- Review and incorporate new best practices
- Update tool configurations as codebase evolves
- Train team on new quality requirements

## Training and Onboarding

### New Developer Checklist:
- [ ] Understand quality gate philosophy
- [ ] Run `./script/dev/quality` successfully
- [ ] Review tool configurations and rationale
- [ ] Practice fixing common quality issues
- [ ] Understand accessibility and i18n requirements

### Continuous Learning:
- Regular code review focused on quality
- Quality-focused pair programming sessions
- Tool-specific training sessions
- Stay updated with Rails/Ruby best practices

## Rationale and Philosophy

These quality standards exist to:

1. **Prevent technical debt** from accumulating
2. **Ensure maintainability** as the codebase grows
3. **Provide safety** for a multi-tenant production system
4. **Enable confidence** in making changes
5. **Support accessibility** for all users
6. **Maintain security** in a web-facing application
7. **Optimize performance** for end users
8. **Enable internationalization** for global use

Remember: Quality is not optional. It's an investment in the future of the codebase and the success of the project.