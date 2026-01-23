# Task: Add Monetisation UI Components

## Metadata

| Field | Value |
|-------|-------|
| ID | `003-001-monetisation-ui-components` |
| Status | `todo` |
| Priority | `003` Medium |
| Created | `2026-01-23 10:15` |
| Started | |
| Completed | |
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
- [ ] Public listing index shows "Featured" section at top
- [ ] Featured section only displays when featured listings exist
- [ ] Featured listings appear in both Featured section AND normal listing

### Featured/Sponsored Badges
- [ ] Featured listings display "Featured" or "Sponsored" badge
- [ ] Badge styling is consistent with site design
- [ ] Badge is accessible (proper contrast, screen reader support)

### Job Listing Enhancements
- [ ] Job listings display company name
- [ ] Job listings display location
- [ ] Job listings display salary range (if present)
- [ ] Job listings display "Apply" button/link to apply_url
- [ ] Expired jobs not displayed in public views

### Affiliate Link Integration
- [ ] Links to external sites use `display_url` (which returns affiliate URL when configured)
- [ ] OR links use `/go/:id` redirect endpoint for tracking

### Admin Forms
- [ ] Admin listing form includes monetisation fields:
  - listing_type dropdown
  - affiliate_url_template field
  - affiliate_attribution JSON editor
  - featured_from/featured_until date pickers
  - expires_at date picker
  - company, location, salary_range, apply_url fields (for jobs)
  - paid checkbox, payment_reference field
- [ ] Conditional display based on listing_type (job fields only show for jobs)

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

*(empty - task not started)*

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
