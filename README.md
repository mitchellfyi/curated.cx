# Curated

**Launch your own content network in minutes.**

Curated is a multi-tenant content platform that lets you create interconnected niche content sites—each with its own domain, branding, and community—all managed from a single codebase.

## Why Curated?

- **One Platform, Many Sites**: Run dozens of niche content sites from a single Rails application
- **Network Effects**: Cross-promote content across your network with built-in discovery
- **Own Your Audience**: Each site gets its own domain, SEO, and brand identity
- **Content Aggregation**: Automatically pull content from RSS feeds, APIs, and custom sources
- **Marketplace Ready**: Built-in listings system for directories, jobs, or classifieds
- **Enterprise-Grade Quality**: Automated testing, security scanning, and accessibility compliance

## How It Works

### The Network Hub (curated.cx)

The root domain serves as your network's home base:
- **Site Directory**: Showcase all sites in your network
- **Cross-Network Feed**: Surface the best content from across all sites
- **Network Stats**: Display collective metrics (sites, content, listings)
- **Marketing Pages**: Pricing, features, and onboarding for new publishers

### Tenant Sites (yoursite.cx)

Each tenant site is a fully-featured content hub:
- **Content Feed**: Aggregated articles ranked by engagement and freshness
- **Listings by Category**: Organized marketplace or directory sections
- **Custom Branding**: Unique logo, colors, and domain
- **Independent SEO**: Per-site meta tags, sitemaps, and structured data

## Live Network

| Site | Domain | Focus |
|------|--------|-------|
| Curated Hub | [curated.cx](https://curated.cx) | Network directory & discovery |
| AI News | [ainews.cx](https://ainews.cx) | Artificial intelligence news |
| Construction | [construction.cx](https://construction.cx) | Construction industry news |
| DayZ | [dayz.cx](https://dayz.cx) | DayZ gaming community |

---

## Getting Started

### Prerequisites

- Ruby 3.4.2 (see `.ruby-version`)
- Node.js 20+ (see `.node-version`)
- PostgreSQL 16+

### Quick Start

```bash
# Clone and setup
git clone https://github.com/mitchellfyi/curated.cx.git
cd curated.cx
./bin/setup

# Start development server
./bin/dev

# Run the test suite
bundle exec rspec

# Run quality checks
./bin/quality
```

### Local Development Domains

Access different tenants using local domain patterns:

| URL | Tenant |
|-----|--------|
| `http://localhost:3000` | Root hub (network directory) |
| `http://ai.localhost:3000` | AI News tenant |
| `http://construction.localhost:3000` | Construction tenant |

The tenant resolver automatically handles `localhost` and subdomain patterns in development.

---

## Architecture

### Multi-Tenant Design

```
Tenant (curated.cx)
  └── Site
       ├── Domains (ainews.cx, www.ainews.cx)
       ├── Sources (RSS feeds, APIs)
       ├── ContentItems (articles, posts)
       ├── Categories
       └── Listings (directory entries)
```

- **Row-Level Isolation**: All data scoped via `acts_as_tenant`
- **Domain Resolution**: Automatic tenant detection from request hostname
- **Cross-Site Queries**: Network-wide content aggregation for root tenant

### Content Pipeline

1. **Sources**: Configure RSS feeds or API endpoints per site
2. **Ingestion**: Background jobs fetch and normalize content
3. **Ranking**: FeedRankingService scores content by freshness and engagement
4. **Display**: Responsive cards with source attribution

### Key Services

| Service | Purpose |
|---------|---------|
| `NetworkFeedService` | Cross-network content aggregation |
| `TenantHomepageService` | Homepage data orchestration |
| `FeedRankingService` | Content ranking algorithm |
| `ContentRecommendationService` | Personalized content recommendations |
| `TenantResolver` | Domain-to-tenant resolution |
| `ReferralAttributionService` | Referral tracking with fraud prevention |
| `ReferralRewardService` | Milestone detection and reward tracking |
| `DigitalProductCheckoutService` | Digital product purchases via Stripe |
| `MuxLiveStreamService` | Live video streaming via Mux |
| `MuxWebhookHandler` | Mux webhook event processing |

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| Framework | Rails 8.0 |
| Database | PostgreSQL 16 |
| Background Jobs | Solid Queue |
| Caching | Solid Cache |
| Search | pg_search |
| Frontend | Hotwire (Turbo + Stimulus) |
| Styling | Tailwind CSS |
| Auth | Devise |

---

## Quality Assurance

This codebase enforces quality automatically via git hooks and CI/CD.

### The 12 Quality Gates

Every commit must pass:

1. **Code Style** - RuboCop (Rails Omakase)
2. **Security** - Brakeman + Bundle Audit
3. **Tests** - RSpec with 80% coverage minimum
4. **Route Testing** - All routes must have tests
5. **i18n** - No hardcoded strings
6. **Template Quality** - ERB lint + semantic HTML
7. **SEO** - Meta tags and structured data
8. **Accessibility** - WCAG 2.1 AA via axe-core
9. **Performance** - No N+1 queries (Bullet)
10. **Database** - Safe migrations (Strong Migrations)
11. **Multi-tenant** - Data isolation verification
12. **Documentation** - Sync checks

### Running Quality Checks

```bash
# Full quality suite (required before commit)
./bin/quality

# Real-time monitoring during development
bundle exec guard

# Quality dashboard
./script/dev/quality-dashboard
```

---

## Development Tools

### Testing

```bash
bundle exec rspec                     # Full test suite
bundle exec rspec spec/models/        # Model specs only
bundle exec rspec --tag ~slow         # Skip slow tests
```

### Code Quality

```bash
bundle exec rubocop                   # Style check
bundle exec rubocop -A                # Auto-fix
bundle exec brakeman                  # Security scan
bundle exec i18n-tasks health         # Translation health
```

### Database

```bash
bundle exec rails db:migrate          # Run migrations
./script/dev/migration-check          # Migration safety analysis
bundle exec annotaterb models         # Update model annotations
```

### Utilities

```bash
./script/dev/i18n                     # Manage translations
./script/dev/route-test-check         # Verify route coverage
./script/dev/quality-check-file FILE  # Check specific file
```

---

## Internationalization

### Supported Locales

- **English (en)** - Default
- **Spanish (es)** - Additional

### Accessibility

- WCAG 2.1 AA compliance
- Semantic HTML with proper landmarks
- Screen reader support
- Keyboard navigation
- Skip links and focus management
- Reduced motion support

---

## Environment Variables

### Required

| Variable | Description |
|----------|-------------|
| `RAILS_MASTER_KEY` | Rails credentials decryption key |
| `DATABASE_URL` | PostgreSQL connection URL |

### Optional (Feature-Specific)

| Variable | Description |
|----------|-------------|
| `MUX_TOKEN_ID` | Mux API token ID (for live streaming) |
| `MUX_TOKEN_SECRET` | Mux API token secret (for live streaming) |
| `MUX_WEBHOOK_SECRET` | Mux webhook signature verification secret |

---

## Deployment

Deployed to Dokku with automatic SSL via Let's Encrypt.

```bash
# Deploy (automatic on push to main)
git push dokku main

# Manual deployment
./bin/deploy
```

See `docs/deploy-dokku.md` for detailed instructions.

### CI/CD Pipeline

- **Lint & Format**: RuboCop, ERB Lint, ESLint
- **Security**: Brakeman, Bundle Audit, npm audit
- **Tests**: RSpec with coverage
- **Build**: Asset compilation verification
- **Deploy**: Automatic on main branch

---

## Documentation

| Document | Description |
|----------|-------------|
| [docs/README.md](docs/README.md) | Documentation index |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | System design and data model |
| [docs/deploy-dokku.md](docs/deploy-dokku.md) | Deployment guide |
| [docs/quality-enforcement.md](docs/quality-enforcement.md) | Quality system details |
| [docs/safe-migrations.md](docs/safe-migrations.md) | Migration best practices |

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes (quality gates will guide you)
4. Commit (`git commit -m 'feat: Add amazing feature'`)
5. Push (`git push origin feature/amazing-feature`)
6. Open a Pull Request

All PRs must pass CI checks before merge.

---

## License

Proprietary. All rights reserved.

---

Built with Rails 8 by [Mitchell](https://mitchell.fyi)
