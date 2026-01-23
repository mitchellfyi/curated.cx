# Curated.www

A multi-tenant curated content platform built with Rails 8.

## Development Setup

### Prerequisites

- Ruby 3.4.2 (see `.ruby-version`)
- Node.js (see `.node-version`)
- PostgreSQL
- Redis (for background jobs)

### Quick Start

```bash
# Setup development environment
./bin/setup

# Start the development server (includes quality automation via Guard)
./bin/dev

# Run tests
bundle exec rspec

# Run code quality checks
./bin/quality
```

### Multi-Tenant Local Domains

This is a multi-tenant application. In development, you can access different tenants using local domain patterns:

**Root Tenant (Hub)**
- `http://localhost:3000` - Access the root tenant (slug: `root`)

**Subdomain Tenants**
- `http://ai.localhost:3000` - Access the AI News tenant (slug: `ai`)
- `http://construction.localhost:3000` - Access the Construction tenant (slug: `construction`)

To use subdomain.localhost patterns, you may need to configure your `/etc/hosts` file (optional but recommended):

```bash
# Add to /etc/hosts for easier subdomain access
127.0.0.1 ai.localhost
127.0.0.1 construction.localhost
```

**Note:** The tenant resolver automatically handles `localhost`, `127.0.0.1`, and subdomain patterns like `subdomain.localhost` in development mode. Plain `localhost` resolves to the root tenant, while `subdomain.localhost` resolves to the tenant matching that slug.

## Development Tools

This project includes comprehensive development tools for code quality, security, and testing:

### Testing
- **RSpec** - Behavior-driven testing framework
- **Factory Bot** - Test data generation
- **Faker** - Realistic fake data for tests
- **Database Cleaner** - Clean database state between tests
- **SimpleCov** - Code coverage analysis (80% minimum threshold)

### Code Quality & Security
- **Brakeman** - Security vulnerability scanner
- **RuboCop Rails Omakase** - Code style enforcement
- **Bullet** - N+1 query detection
- **Prosopite** - Alternative N+1 query detection

### Development Experience
- **Better Errors** - Enhanced error pages
- **Letter Opener** - Email preview in development
- **Listen** - File system change monitoring
- **Annotaterb** - Annotate models with schema information (Rails 8 compatible)
- **Meta Tags** - SEO and social media meta tags management
- **Strong Migrations** - Safe database migration practices
- **Draper** - Object-oriented presentation logic with decorators

### Internationalization
- **i18n-tasks** - Manage missing and unused translations

### Running Tools Individually

```bash
bundle exec rspec                    # Run test suite
bundle exec brakeman                 # Security scan
bundle exec rubocop                  # Code style check
bundle exec bullet                   # N+1 query detection (via web interface)
bundle exec annotaterb models        # Annotate models with schema info
bundle exec i18n-tasks health        # Check i18n translation health
```

### Development Scripts

```bash
./bin/setup                           # Setup development environment
./script/dev/setup-quality-automation # Setup autonomous quality system
./bin/quality                        # **MANDATORY** - Run ALL quality checks
./script/dev/pre-push-quality        # Extended pre-push validation
./script/dev/quality-dashboard       # Live quality metrics and status
./script/dev/quality-check-file      # File-specific quality checks
./script/dev/i18n-check-file         # i18n compliance for templates
./script/dev/route-test-check        # Route testing validation
./script/dev/migration-check         # Migration safety analysis
./script/dev/i18n                    # Manage i18n translations
./script/dev/migrations              # Database migration safety tools
bundle exec guard                    # **RECOMMENDED** - Real-time quality monitoring
```

## Autonomous Quality Enforcement System (CRITICAL)

**This codebase has a fully autonomous quality enforcement system that prevents poor implementations automatically.**

### 🛡️ **Multi-Layer Protection System**:

#### **Layer 1: Real-time Monitoring**
```bash
bundle exec guard  # Monitors files and runs quality checks automatically
```

#### **Layer 2: Pre-commit Hooks (Overcommit)**
- **Automatically blocks commits** that fail quality gates
- **12 comprehensive checks** run before every commit
- **Zero bypass mechanisms** - quality failures prevent commits

#### **Layer 3: Pre-push Hooks**
- **Extended validation** before pushing to remote
- **Database integrity** and schema validation
- **Documentation synchronization** checks
- **Deployment readiness** verification

#### **Layer 4: CI/CD Pipeline**
- **Comprehensive automated testing** on every push
- **Production build validation**
- **Security monitoring**

### 🚀 **Getting Started with Autonomous Quality**:

```bash
# 1. Setup the autonomous system (run once)
./script/dev/setup-quality-automation

# 2. Start real-time monitoring (run during development)
bundle exec guard

# 3. Check quality status anytime
./script/dev/quality-dashboard

# 4. Develop normally - the system guides you automatically
# Pre-commit and pre-push hooks run automatically
# Guard provides real-time feedback on file changes
```

## Quality Enforcement (AUTONOMOUS SYSTEM)

**Every code change is automatically validated by a comprehensive autonomous quality system:**

```bash
./bin/quality  # Must pass 100% - enforced automatically via git hooks
```

### 🛡️ **The 12 Autonomous Quality Gates**:
- ✅ **Code Style**: Zero RuboCop violations (Rails Omakase) + SOLID principles
- ✅ **Security**: Zero Brakeman high/medium issues + Bundle Audit
- ✅ **Tests**: 100% passing, 80% minimum coverage + Test Pyramid compliance
- ✅ **Route Testing**: Every route must have corresponding tests (automated check)
- ✅ **i18n**: All static text uses translation keys (hardcoded string detection)
- ✅ **Template Quality**: ERB lint compliance + semantic HTML
- ✅ **SEO**: Meta tags, structured data, XML sitemaps (automated validation)
- ✅ **Accessibility**: WCAG 2.1 AA compliance via axe-core testing
- ✅ **Performance**: No N+1 queries + response time monitoring
- ✅ **Database**: Proper indexes, constraints, migration safety
- ✅ **Multi-tenant**: acts_as_tenant verification + data isolation
- ✅ **Documentation**: Synchronization and consistency checks

### 🤖 **Fully Automated Protection**:
- **Pre-commit hooks** block commits that fail quality gates
- **Pre-push hooks** run extended validation before pushing
- **Real-time monitoring** via Guard provides immediate feedback
- **CI/CD pipeline** ensures production readiness
- **Quality dashboard** provides live metrics and guidance

**Documentation**: See `doc/QUALITY_AUTOMATION.md` for complete autonomous system guide.

## Internationalization & Accessibility

The application is designed with internationalization in mind:

### Supported Locales
- **English (en)** - Default locale
- **Spanish (es)** - Additional locale

### Accessibility Features
- WCAG 2.1 AA compliance testing with axe-core
- Semantic HTML structure with proper landmarks
- Screen reader compatibility with sr-only text
- Keyboard navigation support with focus management
- Color contrast validation and high contrast mode support
- Skip links for improved navigation
- Reduced motion support for accessibility preferences

### Configuration
- Locale detection and fallbacks configured in `config/application.rb`
- Translation files in `config/locales/`

## Architecture Patterns

### Decorators (Draper)
The application uses the **Decorator pattern** via Draper to handle presentation logic, keeping views clean and models focused on business logic.

#### Key Benefits
- **Separation of Concerns**: Model logic stays in models, presentation logic in decorators
- **Testable**: Decorators are easily unit tested independently
- **Reusable**: Presentation logic can be shared across different views
- **Object-Oriented**: More maintainable than helper methods

#### Usage Examples
```ruby
# In controllers
@user = current_user.decorate
@tenant = Current.tenant.decorate

# In views
<%= @user.avatar_image(size: 40) %>
<%= @user.role_badges_for_tenant(@tenant) %>
<%= @tenant.logo_image(css_class: "navbar-brand") %>
```

#### Available Decorators
- **UserDecorator**: Avatar handling, role displays, user status
- **TenantDecorator**: Logo management, theme variables, social media tags
- **ApplicationDecorator**: Base decorator with common functionality

### Tenant Branding System
- **Root tenant** (`curated.cx`): Shows directory of all enabled platforms
- **Other tenants**: Display sticky "Powered by Curated.cx" footer at bottom of page
- **Development URLs**: Root tenant uses `http://localhost:3000`, child tenants use `http://slug.localhost:3000`
- **Production URLs**: Uses `https://hostname` for live environments
- **Responsive design**: Directory grid adapts to different screen sizes


# Database Migrations

The application uses **Strong Migrations** to prevent dangerous database migrations that could cause downtime in production.

### Safe Migration Practices
- Add columns without defaults, then backfill data
- Create indexes concurrently on large tables
- Use multi-step approach for column renames
- Test migrations on production-sized datasets

### Migration Tools
```bash
./script/dev/migrations              # Migration safety checker and helper
bundle exec rails db:migrate:status  # Check migration status
```

See `doc/SAFE_MIGRATIONS.md` for detailed examples and best practices.

## Database

- **Primary Database**: PostgreSQL
- **Multi-tenancy**: Using `acts_as_tenant` gem with subdomain-based tenant resolution
- **Background Jobs**: Solid Queue (Rails 8 default)
- **Caching**: Solid Cache (Rails 8 default)

## Key Dependencies

- **Rails 8.0.3** - Web framework
- **Devise** - Authentication
- **pg_search** - Full-text search
- **acts_as_tenant** - Multi-tenancy
- **Tailwind CSS** - Styling
- **Stimulus & Turbo** - Frontend interactions

## Architecture

See `doc/adr/` for Architecture Decision Records documenting major technical decisions.


### Use with Claude

`claude  --allow-dangerously-skip-permissions   --chrome  --dangerously-skip-permissions --model opus --permission-mode dontAsk`

