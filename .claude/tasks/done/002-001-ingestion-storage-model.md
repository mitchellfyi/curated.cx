# Task: Implement Ingestion Storage Model

## Metadata

| Field | Value |
|-------|-------|
| ID | `002-001-ingestion-storage-model` |
| Status | `done` |
| Priority | `002` High |
| Created | `2025-01-23 00:05` |
| Started | `2025-01-23 00:15` |
| Completed | `2025-01-23 00:20` |
| Blocked By | (none) |
| Blocks | `002-002-serpapi-connector`, `002-003-categorisation-system` |

---

## Context

The ingestion pipeline needs a solid data model foundation. This task establishes the core models for pulling content from external sources and storing it in a normalized, deduplicated format.

Key models:
- **Source**: Defines what to pull (query, RSS, publisher, SerpApi params)
- **ImportRun**: A batch execution record with timing, status, errors, counts
- **ContentItem**: The canonical stored item with title, URL, source, raw payload, extracted text, tags, summary

All content is scoped to Site (multi-tenant).

---

## Acceptance Criteria

- [x] Source model exists with proper validations
- [x] ImportRun model exists with status tracking (pending, running, completed, failed)
- [x] ContentItem model exists with all required fields
- [x] ContentItem dedupes by canonical URL per Site
- [x] Raw payload stored for audit and debugging
- [x] All models scoped to Site via acts_as_tenant
- [x] Database indexes on foreign keys and lookup fields
- [x] RSpec tests confirm dedupe logic
- [x] RSpec tests confirm tenant scoping
- [x] `docs/ingestion-model.md` documents the schema
- [x] Quality gates pass (rubocop, brakeman, rspec)
- [x] Changes committed with task reference

---

## Plan

1. **Create Source model**
   - Fields: site_id, name, source_type (enum), config (jsonb), enabled, last_run_at
   - Validations: presence of name, source_type
   - Scoped to Site

2. **Create ImportRun model**
   - Fields: site_id, source_id, status, started_at, completed_at, items_processed, items_created, items_skipped, error_message, metadata (jsonb)
   - Status enum: pending, running, completed, failed
   - Scoped to Site

3. **Create ContentItem model**
   - Fields: site_id, source_id, import_run_id, title, url, canonical_url, content_type, raw_payload (jsonb), extracted_text, summary, why_it_matters, tags (array), published_at, fetched_at
   - Unique constraint: [site_id, canonical_url]
   - Scoped to Site

4. **Add URL canonicalization**
   - Normalize URLs before storage (remove tracking params, normalize protocol)
   - Helper method for canonical URL generation

5. **Write migrations**
   - Follow strong_migrations practices
   - Add proper indexes

6. **Write tests**
   - Model validations
   - Dedupe on canonical URL
   - Tenant scoping isolation

7. **Write documentation**
   - `docs/ingestion-model.md` with ERD and field descriptions

---

## Work Log

**2025-01-23 00:15** - Resumed task. Found all models already implemented:
- `Source` model at `app/models/source.rb` (139 lines)
- `ImportRun` model at `app/models/import_run.rb` (97 lines)
- `ContentItem` model at `app/models/content_item.rb` (97 lines)
- `UrlCanonicaliser` service at `app/services/url_canonicaliser.rb`

**2025-01-23 00:16** - Verified migrations exist:
- `20260120213818_create_import_runs.rb` - Creates import_runs table with status, counts, error tracking
- `20260120213820_create_content_items.rb` - Creates content_items with unique index on `[site_id, url_canonical]`

**2025-01-23 00:17** - Verified test coverage:
- `spec/models/source_spec.rb` - 26 examples
- `spec/models/import_run_spec.rb` - 18 examples
- `spec/models/content_item_spec.rb` - 18 examples
- All 62 tests passing

**2025-01-23 00:18** - Verified documentation exists at `docs/ingestion-model.md` (341 lines)

**2025-01-23 00:19** - Ran full quality gates via `./bin/quality`:
- RuboCop: 183 files, no offenses
- Brakeman: 0 security warnings
- Bundle Audit: no vulnerabilities
- RSpec: 894 examples, 0 failures

**2025-01-23 00:20** - Task complete. All acceptance criteria met.

---

## Testing Evidence

```
$ bundle exec rspec spec/models/source_spec.rb spec/models/import_run_spec.rb spec/models/content_item_spec.rb --format documentation

Source (26 examples, 0 failures)
ImportRun (18 examples, 0 failures)
ContentItem (18 examples, 0 failures)

Finished in 1.02 seconds
62 examples, 0 failures
```

Key tests verified:
- **Dedupe logic**: `ContentItem#deduplication` tests prevent duplicate canonical URLs per site
- **Tenant scoping**: `ImportRun#scoping to Site` and `ContentItem#scoping to Site` confirm isolation
- **Site isolation**: Cross-site access properly raises `ActiveRecord::RecordNotFound`

---

## Notes

- Consider using pg_search for full-text search on extracted_text later
- May need to add soft delete for ContentItem
- Raw payload storage enables reprocessing without refetching

---

## Links

- Mission: `MISSION.md` - "Ingest: pull from selected sources"
- Related: `002-002-serpapi-connector` - First connector implementation
