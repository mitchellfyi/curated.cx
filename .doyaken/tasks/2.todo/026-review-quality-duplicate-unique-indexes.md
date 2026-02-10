# Review duplicate uniqueness constraints on entries table

## Category
Periodic Review Finding - quality

## Severity
medium

## Description
The entries migration creates two different unique indexes that may conflict:

1. `index_entries_on_site_kind_canonical` — UNIQUE on (site_id, entry_kind, url_canonical)
2. `index_entries_on_tenant_and_url_canonical` — UNIQUE on (tenant_id, url_canonical)

The model validates `url_canonical` uniqueness scoped to `[:site_id, :entry_kind]` (matching index 1).

Index 2 means the same URL cannot appear for the same tenant even across different entry kinds or different sites. This could prevent a feed entry and a directory entry from sharing the same canonical URL within a tenant, which may be too restrictive.

## Location
db/migrate/20260210010439_merge_content_item_and_listing_into_entries.rb

## Recommended Fix
1. Decide if tenant-level uniqueness is intentional or should be removed
2. If not needed, remove `index_entries_on_tenant_and_url_canonical`
3. If needed, update the model validation to match both constraints

## Impact
Unexpected uniqueness violations when creating entries; potential data integrity issues

## Acceptance Criteria
- [ ] Uniqueness constraints are intentional and documented
- [ ] Model validation matches database constraints
