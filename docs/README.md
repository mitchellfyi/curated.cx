# Documentation

Technical documentation for the Curated.cx multi-tenant content platform.

## Quick Start

| Document | Description |
|----------|-------------|
| [README](../README.md) | Project overview, setup, and development |
| [MISSION](../MISSION.md) | Vision, goals, and product strategy |
| [ARCHITECTURE](ARCHITECTURE.md) | System design and data model overview |

## Architecture & Data

| Document | Description |
|----------|-------------|
| [Architecture](ARCHITECTURE.md) | System architecture and design patterns |
| [Data Model](DATA_MODEL.md) | Database schema and relationships |
| [Domain Routing](domain-routing.md) | Multi-tenant domain resolution |
| [Ingestion Model](ingestion-model.md) | Content ingestion schema and flow |

## Features

| Document | Description |
|----------|-------------|
| [Background Jobs](background-jobs.md) | Solid Queue configuration and recurring tasks |
| [Editorialisation](editorialisation.md) | AI content enrichment (summaries, tags) |
| [Ranking](ranking.md) | Feed ranking algorithm |
| [Monetisation](monetisation.md) | Affiliate, jobs, and featured listings |
| [Moderation](moderation.md) | Community controls and content flagging |
| [Onboarding](onboarding.md) | Site and domain setup flow |
| [Tagging](tagging.md) | Tag management and organization |

## Growth

| Document | Description |
|----------|-------------|
| [Data Model](DATA_MODEL.md) | See DigestSubscription, Referral, ReferralRewardTier sections |

## Security & Quality

| Document | Description |
|----------|-------------|
| [Security](security.md) | Tenant and site isolation guarantees |
| [Quality Enforcement](quality-enforcement.md) | Quality standards and gates |
| [CI/CD Quality](ci-cd-quality.md) | Continuous integration workflows |
| [Safe Migrations](safe-migrations.md) | Database migration best practices |
| [Anti-Pattern Prevention](anti-pattern-prevention.md) | Code patterns to avoid |
| [Error Handling](error-handling.md) | Error handling patterns |

## Performance & SEO

| Document | Description |
|----------|-------------|
| [SEO Testing](seo-testing.md) | SEO optimization and testing |
| [Cache Key Conventions](cache-key-conventions.md) | Caching patterns and invalidation |

## Integrations

| Document | Description |
|----------|-------------|
| [SerpAPI Connector](connectors/serpapi.md) | Google News ingestion via SerpAPI |

## Deployment

| Document | Description |
|----------|-------------|
| [Dokku Deployment](deploy-dokku.md) | Production deployment guide |

## Development Commands

```bash
# Setup and run
./bin/setup           # Initial setup
./bin/dev             # Start development server

# Quality checks
./bin/quality         # Run all quality gates

# Tests
bundle exec rspec     # Run test suite
```
