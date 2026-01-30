# Monetisation

This document describes the monetisation features in Curated.cx, including affiliate support, job boards, and featured placements.

---

## Overview

Curated.cx supports four revenue streams, all designed to be transparent and user-friendly:

1. **Affiliate Support** - Tool/product listings with affiliate tracking
2. **Job Board** - Paid job posts with expiry management
3. **Featured Placements** - Promoted listings with time-based visibility
4. **Network Boosts** - Cross-network site promotion with CPC pricing

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

### Payment Integration (Stripe)

Stripe Checkout is fully integrated for self-service payments:

**Database Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `paid` | boolean | Payment status |
| `payment_status` | enum | `unpaid`, `pending_payment`, `paid`, `refunded` |
| `stripe_checkout_session_id` | string | Stripe session ID |
| `stripe_payment_intent_id` | string | Stripe payment intent ID |

**Checkout Types:**

| Type | Duration | Price |
|------|----------|-------|
| `job_post_30` | 30 days | $99 |
| `job_post_60` | 60 days | $149 |
| `job_post_90` | 90 days | $199 |
| `featured_7` | 7 days | $49 |
| `featured_14` | 14 days | $89 |
| `featured_30` | 30 days | $149 |

**Services:**

- `StripeCheckoutService` - Creates checkout sessions
- `StripeWebhookHandler` - Processes webhook events
- `PaymentReceiptMailer` - Sends receipts

**Routes:**

| Method | Path | Description |
|--------|------|-------------|
| GET | `/listings/:id/checkout` | Show checkout options |
| POST | `/listings/:id/checkout` | Create Stripe session |
| GET | `/listings/:id/checkout/success` | Success callback |
| GET | `/listings/:id/checkout/cancel` | Cancel callback |
| POST | `/stripe/webhooks` | Webhook endpoint |

**Webhook Events:**

- `checkout.session.completed` - Mark as paid, set expiry
- `checkout.session.expired` - Reset to unpaid
- `charge.refunded` - Mark as refunded, remove benefits

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

## Network Boosts

Network Boosts enable cross-network site promotion where publishers can recommend other network sites to their subscribers and earn CPC (cost-per-click) revenue for conversions.

### How It Works

1. **Source site** promotes a **target site** to its subscribers
2. Impressions are shown in recommendation widgets
3. Clicks are tracked with 24h deduplication
4. Conversions are attributed within a 30-day window
5. Source site earns CPC rate for confirmed clicks

### Database Models

#### NetworkBoost (Campaign)

| Field | Type | Description |
|-------|------|-------------|
| `source_site_id` | bigint | Site showing the boost |
| `target_site_id` | bigint | Site being promoted |
| `cpc_rate` | decimal | Cost per click (paid to source site) |
| `monthly_budget` | decimal | Monthly spend cap (nil = unlimited) |
| `spent_this_month` | decimal | Current month's spend |
| `enabled` | boolean | Whether boost is active |

**Scopes:**
- `enabled` - Active boosts only
- `with_budget` - Boosts with remaining budget
- `for_source_site(site)` - Boosts from a site
- `for_target_site(site)` - Boosts to a site

#### BoostImpression (Views)

| Field | Type | Description |
|-------|------|-------------|
| `network_boost_id` | bigint | The boost campaign |
| `site_id` | bigint | Where the boost was shown |
| `ip_hash` | string | Hashed viewer IP (privacy) |
| `shown_at` | datetime | When shown |

**Scopes:**
- `today`, `this_week`, `this_month` - Temporal filters
- `for_boost(boost)` - Impressions for a specific boost

#### BoostClick (Clicks)

| Field | Type | Description |
|-------|------|-------------|
| `network_boost_id` | bigint | The boost campaign |
| `ip_hash` | string | Hashed clicker IP |
| `clicked_at` | datetime | When clicked |
| `converted_at` | datetime | When subscription was created |
| `digest_subscription_id` | bigint | Resulting subscription |
| `earned_amount` | decimal | CPC rate at time of click |
| `status` | enum | `pending`, `confirmed`, `paid`, `cancelled` |

**Lifecycle:**
1. `pending` - Click recorded, awaiting 24h verification
2. `confirmed` - Verified after 24h
3. `paid` - Included in a payout
4. `cancelled` - Fraud detected or manually cancelled

**Scopes:**
- `recent`, `today`, `this_week`, `this_month` - Temporal filters
- `converted`, `unconverted` - Conversion status
- `within_attribution_window(ip_hash)` - 30-day lookback

#### BoostPayout (Payments)

| Field | Type | Description |
|-------|------|-------------|
| `site_id` | bigint | Site receiving payout |
| `amount` | decimal | Payout amount |
| `period_start` | date | Period start |
| `period_end` | date | Period end |
| `status` | enum | `pending`, `paid`, `cancelled` |
| `paid_at` | datetime | When paid |
| `payment_reference` | string | External payment ID |

### Services

#### BoostAttributionService

Handles click tracking and conversion attribution:

```ruby
# Record a click (returns nil if deduplicated)
BoostAttributionService.record_click(boost: boost, ip: request.remote_ip)

# Attribute a conversion to a previous click
BoostAttributionService.attribute_conversion(
  subscription: subscription,
  ip: request.remote_ip
)

# Calculate earnings for a site
BoostAttributionService.calculate_earnings(
  site: site,
  start_date: 1.month.ago,
  end_date: Time.current
)

# Get stats for a boost
BoostAttributionService.boost_stats(boost, since: 30.days.ago)
# => { impressions: 1000, clicks: 50, conversions: 5, click_rate: 5.0, conversion_rate: 10.0, earnings: 25.0 }
```

#### NetworkBoostService

Selects appropriate boosts to display:

```ruby
# Get boosts for a site (excludes user's subscribed sites)
NetworkBoostService.for_site(site, user: current_user, limit: 3)
```

### Attribution Rules

| Rule | Value |
|------|-------|
| Attribution window | 30 days |
| Click deduplication | 24 hours per IP per boost |
| Confirmation delay | 24 hours |
| IP privacy | SHA256 hashed with app secret |

### Admin Routes

| Method | Path | Description |
|--------|------|-------------|
| GET | `/admin/network_boosts` | List boost campaigns |
| POST | `/admin/network_boosts` | Create boost campaign |
| PATCH | `/admin/network_boosts/:id` | Update boost |
| DELETE | `/admin/network_boosts/:id` | Delete boost |
| GET | `/admin/boost_earnings` | View earnings dashboard |
| GET | `/admin/boost_payouts` | View payouts |
| PATCH | `/admin/boost_payouts/:id` | Mark payout as paid |

### Click Tracking Route

| Method | Path | Description |
|--------|------|-------------|
| GET | `/boosts/:id/click` | Track click and redirect to target |

### Site Configuration

Sites can configure boost settings via the `config` JSONB field:

```ruby
site.boosts_enabled?       # => true/false
site.boost_cpc_rate        # => 0.50 (default)
site.boost_monthly_budget  # => nil (unlimited) or amount

# In site config
{
  "boosts": {
    "enabled": true,
    "cpc_rate": "0.50",
    "monthly_budget": "100.00"
  }
}
```

### Conversion Flow

1. User visits source site
2. Boost recommendation widget shows target site
3. `BoostImpression` recorded
4. User clicks boost link → `/boosts/:id/click`
5. `BoostClick` created (if not deduplicated)
6. `ConfirmBoostClickJob` scheduled for 24h
7. User redirected to target site
8. User subscribes to target site
9. `BoostAttributionService.attribute_conversion` called
10. Click marked as converted

### Fraud Prevention

- **IP deduplication**: Same IP can only trigger one click per boost per 24h
- **24h confirmation**: Clicks require 24h delay before confirmation
- **30-day window**: Conversions only attributed within 30 days of click
- **IP hashing**: IPs stored as SHA256 hash for privacy
- **Manual review**: Admin can cancel suspicious clicks

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
| `index_network_boosts_on_source_site_id_and_target_site_id` | `source_site_id, target_site_id` | Boost uniqueness |
| `index_network_boosts_on_target_site_id_and_enabled` | `target_site_id, enabled` | Boost selection |
| `index_boost_clicks_on_ip_hash_and_clicked_at` | `ip_hash, clicked_at` | Click deduplication |
| `index_boost_clicks_on_network_boost_id_and_clicked_at` | `network_boost_id, clicked_at` | Click analytics |
| `index_boost_payouts_on_site_id_and_period_start` | `site_id, period_start` | Payout queries |

---

## API Routes

| Method | Path | Description |
|--------|------|-------------|
| GET | `/go/:id` | Affiliate redirect with tracking |
| POST | `/admin/listings/:id/feature` | Set featured status |
| POST | `/admin/listings/:id/unfeature` | Clear featured status |
| POST | `/admin/listings/:id/extend_expiry` | Extend job expiry |
| GET | `/boosts/:id/click` | Boost click tracking with redirect |

---

## Site-Level Configuration

Monetisation can be enabled/disabled per site via the `config` JSONB field:

```ruby
site.monetisation_enabled?  # => true/false
site.boosts_enabled?        # => true/false

# In site config
{
  "monetisation": {
    "enabled": true
  },
  "boosts": {
    "enabled": true,
    "cpc_rate": "0.50",
    "monthly_budget": "100.00"
  }
}
```

---

## Future Enhancements

- **Premium listings**: Tiered placement options with different visibility levels
- **Subscription plans**: Recurring payment options for ongoing featured placement
- **Stripe Connect payouts**: Automatic payout processing for Network Boosts
- **Boost auction system**: Real-time bidding for boost placements
- **Quality scoring**: Eligibility requirements for boost participation

---

*Last Updated: 2026-01-30*
