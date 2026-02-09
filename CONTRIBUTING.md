# Contributing to Curated

Thank you for your interest in contributing to Curated! This guide covers how CI/CD works, how to run checks locally, and how deployments are handled.

## CI/CD Overview

### Workflow Files

| Workflow | File | Trigger | Purpose |
|----------|------|---------|---------|
| **CI** | `ci.yml` | Push to `develop`, PRs to `main`/`develop`, called by deploy | Linting, security, tests, build verification, quality analysis |
| **Deploy** | `deploy.yml` | Push to `main`, manual dispatch | Runs CI then deploys to Dokku production |
| **Release** | `release.yml` | After successful deploy | Creates a GitHub release with changelog |
| **Security** | `security.yml` | PRs, daily schedule, manual dispatch | Deep security scanning (Semgrep, TruffleHog, GitLeaks, Trivy) |

### CI Pipeline Stages

The CI workflow runs in stages:

1. **Stage 1 — Fast Feedback** (parallel):
   - **Code Style**: RuboCop, ERB Lint, ESLint, Prettier
   - **Security**: Brakeman, Bundle Audit, npm audit
   - **Tests**: RSpec with coverage reporting

2. **Stage 2 — Build Verification** (after Stage 1 passes):
   - Production asset compilation and precompilation

3. **Stage 3 — Advisory Quality Checks** (non-blocking, after tests pass):
   - Rails Best Practices, i18n health, RubyCritic, Reek

4. **Stage 4 — Summary**:
   - Aggregates results and reports pass/fail

### Quality Gates (Must Pass)

- **RuboCop** — Ruby style enforcement (Rails Omakase)
- **ERB Lint** — Template quality checks
- **ESLint** — JavaScript linting
- **Prettier** — JavaScript formatting
- **Brakeman** — Static security analysis
- **Bundle Audit** — Ruby dependency vulnerability scan
- **RSpec** — Full test suite with coverage
- **Asset Build** — Production compilation verification

## Running Checks Locally

Before pushing, run these checks to catch issues early:

```bash
# Full quality suite (recommended before pushing)
./bin/quality

# Individual checks:
bundle exec rubocop --format progress       # Ruby style
bundle exec erb_lint app/views/             # ERB templates
npm run lint                                 # JavaScript lint
npm run format:check                         # Prettier check

# Security
bundle exec brakeman -q --no-pager          # Static security scan
bundle exec bundle-audit check --update     # Dependency audit

# Tests
bundle exec rspec                            # Full test suite
bundle exec rspec spec/models/              # Model specs only

# Build verification
npm run build && npm run build:css           # Asset build
RAILS_ENV=production SECRET_KEY_BASE=dummy bundle exec rails assets:precompile
```

## Deployment

### How Deploys Work

1. Code is merged to `main`
2. The **Deploy to Dokku** workflow triggers automatically
3. CI runs first — all quality gates must pass
4. If CI passes, the app is deployed to Dokku via git push
5. Database migrations run automatically
6. A post-deployment health check verifies the app is responding
7. On success, a GitHub Release is created automatically

### Deploy Safety Features

- **CI gate**: Deploy only proceeds after all CI checks pass
- **Concurrency**: Only one deploy runs at a time; newer pushes cancel in-progress deploys
- **Pre-deploy backup**: Database is backed up before migrations
- **Health checks**: Pre and post-deployment health verification
- **Automatic rollback**: If deployment fails and the app was previously healthy, it rolls back to the previous release

### Manual Deployment

You can trigger a deploy manually from the GitHub Actions tab:

1. Go to **Actions** → **Deploy to Dokku**
2. Click **Run workflow**
3. Options:
   - **Skip migrations**: Set to `true` to skip `db:migrate`
   - **Force deploy**: Set to `true` to continue even if health check fails
   - **Rollback SHA**: Enter a specific commit SHA to deploy (for rollback)

### Rollback

If a bad deploy lands:

1. **Automatic**: The deploy workflow attempts automatic rollback on failure
2. **Manual via workflow dispatch**: Go to Actions → Deploy to Dokku → Run workflow, enter the last known good commit SHA in the "Rollback SHA" field
3. **Manual via CLI**: `git push dokku <good-commit-sha>:refs/heads/main --force`

## Branch Protection

The `main` branch should have these protection rules configured:

- ✅ Require status checks to pass before merging (CI must pass)
- ✅ Require at least one approval on pull requests
- ✅ Do not allow force pushes
- ✅ Require linear history (squash or rebase merges preferred)

## Supply Chain Security

All third-party GitHub Actions are pinned to full SHA commit hashes (not tags) to prevent supply chain attacks. When updating an action:

1. Find the new version's commit SHA from the action's GitHub repository
2. Update the SHA in the workflow file
3. Add a comment with the version tag for reference: `# v6.0.2`

## Commit Message Format

```
type(scope): description
```

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`

Examples:
- `feat(sources): Add Reddit source type`
- `fix(ci): Pin actions to SHA hashes`
- `docs: Update CONTRIBUTING.md`
