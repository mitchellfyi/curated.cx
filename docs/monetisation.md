# Monetisation

This document describes the monetisation features in Curated.cx, including affiliate support, job boards, and featured placements.

---

## Overview

Curated.cx supports three revenue streams, all designed to be transparent and user-friendly:

1. **Affiliate Support** - Tool/product listings with affiliate tracking
2. **Job Board** - Paid job posts with expiry management
3. **Featured Placements** - Promoted listings with time-based visibility

All monetised content is clearly labeled in the UI ("Featured", "Sponsored") to maintain user trust.

---

## Affiliate Support

Affiliate support enables tracking outbound clicks to vendor sites with affiliate attribution.

### Database Fields (Listing model)

| Field | Type | Description |
|-------|------|-------------|
| `affiliate_url_template` | text | URL template with placeholders |
| `affiliate_attribution` | jsonb | Additional tracking parameters |

### URL Template Placeholders

The `affiliate_url_template` field supports these placeholders:

- `{url}` - The canonical URL (URL-encoded)
- `{title}` - The listing title (URL-encoded)
- `{id}` - The listing ID

**Example templates:**
```
https://affiliate.example.com?url={url}&ref=curated
https://go.vendor.com/track?target={url}&campaign=tools
```

### Attribution Parameters

The `affiliate_attribution` JSONB field stores additional query parameters:

```json
{
  "source": "curated",
  "medium": "affiliate",
  "campaign": "tools"
}
```

These are appended to the generated URL automatically.

### Click Tracking

Clicks are tracked via the `/go/:id` redirect endpoint:

1. User clicks affiliate link
2. Request goes to `/go/:listing_id`
3. `AffiliateRedirectsController` records click in `affiliate_clicks` table
4. User is redirected to the affiliate URL

**Privacy**: IP addresses are hashed (SHA256, truncated) before storage.

### AffiliateClick Model

Tracks individual affiliate link clicks for analytics:

| Field | Type | Description |
|-------|------|-------------|
| `listing_id` | bigint | Reference to the listing |
| `clicked_at` | datetime | When the click occurred |
| `ip_hash` | string | Hashed IP for fraud detection |
| `user_agent` | string | Browser user agent (truncated) |
| `referrer` | text | Referring page URL (truncated) |

**Scopes:**
- `recent` - Ordered by most recent
- `today` - Clicks from today
- `this_week` - Clicks from past 7 days
- `this_month` - Clicks from past 30 days
- `for_site(site_id)` - Clicks for a specific site

### Admin Management

Admins can configure affiliate settings in the listing edit form:

- Set `affiliate_url_template` with vendor's tracking URL
- Configure `affiliate_attribution` for additional params
- View click counts (future: analytics dashboard)

---

## Job Board

The job board feature enables paid job postings with automatic expiry.

### Database Fields (Listing model)

| Field | Type | Description |
|-------|------|-------------|
| `listing_type` | integer (enum) | `tool`, `job`, or `service` |
| `company` | string | Company name |
| `location` | string | Job location (e.g., "Remote", "San Francisco, CA") |
| `salary_range` | string | Salary range (e.g., "$80k-$120k") |
| `apply_url` | text | Direct application URL |
| `expires_at` | datetime | When the job expires |
| `paid` | boolean | Whether payment was received |
| `payment_reference` | string | Payment provider reference (e.g., Stripe) |

### Listing Types

```ruby
enum :listing_type, { tool: 0, job: 1, service: 2 }
```

Use `listing.job?`, `listing.tool?`, `listing.service?` to check type.

### Expiry Logic

Jobs automatically hide from public feeds after `expires_at`:

```ruby
# Check if expired
listing.expired?  # => true/false

# Scope for active jobs
Listing.active_jobs  # => jobs.not_expired.published
Listing.not_expired  # => excludes expired listings
Listing.expired      # => only expired listings
```

### Visibility Rules

| Scope | Description |
|-------|-------------|
| `Listing.jobs` | All job listings |
| `Listing.active_jobs` | Published jobs that haven't expired |
| `Listing.not_expired` | Listings without expiry or not yet expired |

### Payment Integration (Stub)

Payment integration is stubbed for future implementation:

- `paid` field tracks payment status
- `payment_reference` stores external payment ID (e.g., Stripe)
- Currently admin-managed; no public submission form

### Admin Management

Admin routes for job management:

```
POST /admin/listings/:id/extend_expiry
```

Parameters:
- `days` (integer) - Number of days to extend (default: 30)

---

## Featured Placements

Featured placements promote listings to prominent positions with clear labeling.

### Database Fields (Listing model)

| Field | Type | Description |
|-------|------|-------------|
| `featured_from` | datetime | When featuring starts |
| `featured_until` | datetime | When featuring ends (nil = indefinite) |
| `featured_by_id` | bigint | Admin who set featured status |

### Featured Logic

```ruby
# Check if currently featured
listing.featured?  # => true/false

# Scopes
Listing.featured      # Currently featured listings
Listing.not_featured  # Not currently featured
```

A listing is featured when:
- `featured_from` is set and in the past
- `featured_until` is nil OR in the future

### Admin Management

Admin routes for featuring:

```
POST /admin/listings/:id/feature
POST /admin/listings/:id/unfeature
```

Feature parameters:
- `featured_until` (datetime, optional) - End date for featuring

Unfeature clears both `featured_from` and `featured_until`.

### UI Display

Featured listings should display:
- "Featured" or "Sponsored" badge
- Appear in dedicated "Featured" section
- Maintain standard listing appearance otherwise

---

## Database Indexes

Optimized indexes for monetisation queries:

| Index | Columns | Purpose |
|-------|---------|---------|
| `index_listings_on_site_featured_dates` | `site_id, featured_from, featured_until` | Featured queries |
| `index_listings_on_site_expires_at` | `site_id, expires_at` | Expiry queries |
| `index_listings_on_site_listing_type` | `site_id, listing_type` | Type filtering |
| `index_listings_on_site_type_expires` | `site_id, listing_type, expires_at` | Active jobs |
| `index_listings_on_featured_by_id` | `featured_by_id` | Admin audit |

---

## API Routes

| Method | Path | Description |
|--------|------|-------------|
| GET | `/go/:id` | Affiliate redirect with tracking |
| POST | `/admin/listings/:id/feature` | Set featured status |
| POST | `/admin/listings/:id/unfeature` | Clear featured status |
| POST | `/admin/listings/:id/extend_expiry` | Extend job expiry |

---

## Site-Level Configuration

Monetisation can be enabled/disabled per site via the `config` JSONB field:

```ruby
site.monetisation_enabled?  # => true/false

# In site config
{
  "monetisation": {
    "enabled": true
  }
}
```

---

## Future Enhancements

- **Payment integration**: Stripe/Lemon Squeezy for job payments
- **Revenue dashboard**: Admin analytics for affiliate clicks and revenue
- **Premium listings**: Tiered placement options
- **Public job submission**: Self-service job posting with payment flow

---

*Last Updated: 2026-01-23*
