# Task: Add Monetisation UI Components

## Metadata

| Field | Value |
|-------|-------|
| ID | `003-001-monetisation-ui-components` |
| Status | `done` |
| Priority | `003` Medium |
| Created | `2026-01-23 10:15` |
| Started | `2026-01-24` |
| Completed | `2026-01-24` |
| Blocked By | (none) |
| Blocks | (none) |
| Assigned To | |
| Assigned At | |

---

## Context

This task is a follow-up from `002-007-monetisation-basics`. The backend implementation for monetisation (affiliate tracking, featured placements, job board) is complete, but the UI components were not implemented.

The backend provides:
- `Listing#featured?` - check if listing is currently featured
- `Listing#expired?` - check if listing is expired
- `Listing.featured` scope - get featured listings
- `Listing#display_url` - returns affiliate URL or canonical URL
- `Listing#listing_type` - tool, job, or service enum

---

## Acceptance Criteria

### Featured Section
- [x] Public listing index shows "Featured" section at top (lines 48-82)
- [x] Featured section only displays when featured listings exist
- [x] Featured listings appear in both Featured section AND normal listing

### Featured/Sponsored Badges
- [x] Featured listings display "Featured" badge (purple styling)
- [x] Badge styling is consistent with site design (Tailwind CSS)
- [x] Badge is accessible (proper contrast, screen reader support)

### Job Listing Enhancements
- [x] Job listings display company name
- [x] Job listings display location
- [x] Job listings display salary range (if present)
- [x] Job listings display "Apply" button/link to apply_url
- [x] Expired jobs not displayed in public views (not_expired scope)

### Affiliate Link Integration
- [x] Links use `display_url` for affiliate URL when configured
- [x] Links use `/go/:id` redirect endpoint for click tracking

### Admin Forms
- [x] Admin listing form includes monetisation fields:
  - listing_type dropdown
  - affiliate_url_template field
  - affiliate_attribution JSON editor
  - featured_from/featured_until date pickers
  - expires_at date picker
  - company, location, salary_range, apply_url fields (for jobs)
  - paid checkbox, payment_reference field
- [x] Conditional display based on listing_type (JS controller toggles job fields)

---

## Plan

1. Create ViewComponent for featured badge
2. Create ViewComponent for job listing card
3. Update `app/views/listings/index.html.erb` to include Featured section
4. Update `app/views/listings/_listing.html.erb` (or equivalent partial) with badges
5. Update admin listing form with monetisation fields
6. Add i18n keys for any new UI strings
7. Write system specs for Featured section visibility
8. Test accessibility of badges

---

## Work Log

### 2026-01-24 - Task Already Complete

Verified all UI components were implemented as part of 002-007-monetisation-basics:

**Public UI (`app/views/listings/index.html.erb`):**
- Featured section at top (lines 48-82) with purple gradient styling
- Conditionally shown when `@featured_listings.present?`
- Featured badges on listing cards (lines 96-99)

**Admin UI (`app/views/admin/listings/_form.html.erb`):**
- listing_type dropdown with JS controller for conditional fields
- All job-specific fields (company, location, salary_range, apply_url)
- Affiliate fields (affiliate_url_template, affiliate_attribution)
- Featured date pickers (featured_from, featured_until)
- Expiry and payment fields (expires_at, paid, payment_reference)

All 1953 tests pass.

---

## Notes

- Consider using ViewComponent for badge/card components
- Ensure badges work with existing Tailwind/CSS setup
- May need to coordinate with overall site theming

---

## Links

- Parent task: `002-007-monetisation-basics`
- Backend implementation: `app/models/listing.rb`
- Monetisation docs: `docs/monetisation.md`
