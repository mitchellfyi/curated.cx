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
./script/dev/setup

# Start the development server
rails server

# Run tests
bundle exec rspec

# Run code quality checks
./script/dev/quality
```

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

### Internationalization & Accessibility
- **i18n-tasks** - Manage missing and unused translations
- **Axe-core RSpec** - Automated accessibility testing
- **Axe-core Capybara** - Accessibility testing in system tests

### Running Tools Individually

```bash
bundle exec rspec                    # Run test suite
bundle exec brakeman                 # Security scan
bundle exec rubocop                  # Code style check
bundle exec bullet                   # N+1 query detection (via web interface)
bundle exec annotaterb models        # Annotate models with schema info
bundle exec i18n-tasks health        # Check i18n translation health
bundle exec rspec spec/system/accessibility_spec.rb  # Run accessibility tests
```

### Development Scripts

```bash
./script/dev/setup                   # Setup development environment
./script/dev/quality                 # Run all quality checks
./script/dev/i18n                    # Manage i18n translations
./script/dev/accessibility           # Run accessibility tests and guidance
```

## Internationalization & Accessibility

The application is designed with internationalization and accessibility in mind:

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

### SEO & Meta Tags
- **Meta Tags Gem** - Comprehensive meta tag management
- Open Graph tags for social media sharing
- Twitter Card support for rich Twitter previews
- Canonical URLs for SEO optimization
- Structured data ready (JSON-LD support)
- Multi-language SEO support

### Configuration
- Locale detection and fallbacks configured in `config/application.rb`
- Translation files in `config/locales/`
- Accessibility helpers in `app/helpers/application_helper.rb`

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
