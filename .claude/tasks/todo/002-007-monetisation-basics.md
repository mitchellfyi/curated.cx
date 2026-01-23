# Task: Add Basic Monetisation Features

## Metadata

| Field | Value |
|-------|-------|
| ID | `002-007-monetisation-basics` |
| Status | `todo` |
| Priority | `002` High |
| Created | `2025-01-23 00:05` |
| Started | |
| Completed | |
| Blocked By | `002-006-community-primitives` |
| Blocks | (none) |

---

## Context

Monetisation is designed into the platform from the start. This task adds the minimum fields and flows to enable revenue without redesigning the app.

Three revenue streams:
1. **Affiliate support** - Tool listings with affiliate URLs
2. **Job board** - Paid job posts with expiry
3. **Featured placements** - Promoted tools and jobs

All must be clearly labeled in UI (transparency).

---

## Acceptance Criteria

### Affiliate Support
- [ ] Tool model (or ContentItem subtype) has affiliate fields:
  - vendor_url
  - affiliate_url_template
  - affiliate_attribution (jsonb for tracking params)
- [ ] Affiliate links used when displaying tools
- [ ] Click tracking for affiliate links
- [ ] Admin can manage affiliate settings per tool

### Job Board
- [ ] JobPost model exists (or ContentItem with type=job)
- [ ] Fields: title, company, location, salary_range, description, apply_url, expires_at, paid
- [ ] Paid job creation flow (stub payment integration)
- [ ] Jobs scoped to Site
- [ ] Expired jobs hidden from public feed
- [ ] Admin can extend/expire jobs manually

### Featured Placements
- [ ] featured_from and featured_until fields on Tool/Job
- [ ] Featured items appear in "Featured" section
- [ ] Featured items labeled clearly in UI ("Featured", "Sponsored")
- [ ] Admin can set/clear featured status

### General
- [ ] Visibility rules respect expiry/featured dates
- [ ] Tests cover expiry logic
- [ ] Tests cover featured visibility
- [ ] `docs/monetisation.md` documents all revenue streams
- [ ] Quality gates pass
- [ ] Changes committed with task reference

---

## Plan

1. **Extend Tool/ContentItem for affiliates**
   - Add affiliate_url_template, affiliate_attribution fields
   - Create AffiliateLink service for URL generation
   - Add click tracking (redirect through internal endpoint)

2. **Create JobPost model** (or extend ContentItem)
   - Core fields: title, company, location, salary_range, description
   - Meta fields: apply_url, expires_at, paid, payment_reference
   - Scoped to Site

3. **Add featured placement fields**
   - featured_from (datetime)
   - featured_until (datetime)
   - featured_by_id (admin who set it)

4. **Implement job creation flow**
   - Public form for job submission
   - Payment step (stub for now - can use Stripe later)
   - Admin approval queue

5. **Add featured sections**
   - "Featured Tools" on tools index
   - "Featured Jobs" on jobs index
   - Clear "Sponsored" labeling

6. **Implement visibility/expiry**
   - Scope queries to exclude expired
   - Scope queries to include featured based on dates
   - Cron job to clean up expired listings

7. **Build admin UI**
   - Affiliate settings for tools
   - Job management (approve, extend, expire)
   - Featured placement toggle

8. **Write tests**
   - Affiliate URL generation
   - Job expiry logic
   - Featured date range logic
   - Visibility scoping

9. **Write documentation**
   - `docs/monetisation.md`
   - How each stream works
   - Pricing guidance (even if stubbed)

---

## Work Log

(To be filled during implementation)

---

## Testing Evidence

(To be filled during implementation)

---

## Notes

- Start with Stripe for payments when ready
- Consider Lemon Squeezy as alternative
- Click tracking important for affiliate revenue measurement
- May want revenue dashboard in admin later
- Premium listings could be a future extension

---

## Links

- Dependency: `002-006-community-primitives`
- Mission: `MISSION.md` - Monetisation section
