# Task: Implement Ingestion Storage Model

## Metadata

| Field | Value |
|-------|-------|
| ID | `002-001-ingestion-storage-model` |
| Status | `todo` |
| Priority | `002` High |
| Created | `2025-01-23 00:05` |
| Started | |
| Completed | |
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

- [ ] Source model exists with proper validations
- [ ] ImportRun model exists with status tracking (pending, running, completed, failed)
- [ ] ContentItem model exists with all required fields
- [ ] ContentItem dedupes by canonical URL per Site
- [ ] Raw payload stored for audit and debugging
- [ ] All models scoped to Site via acts_as_tenant
- [ ] Database indexes on foreign keys and lookup fields
- [ ] RSpec tests confirm dedupe logic
- [ ] RSpec tests confirm tenant scoping
- [ ] `docs/ingestion-model.md` documents the schema
- [ ] Quality gates pass (rubocop, brakeman, rspec)
- [ ] Changes committed with task reference

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

(To be filled during implementation)

---

## Testing Evidence

(To be filled during implementation)

---

## Notes

- Consider using pg_search for full-text search on extracted_text later
- May need to add soft delete for ContentItem
- Raw payload storage enables reprocessing without refetching

---

## Links

- Mission: `MISSION.md` - "Ingest: pull from selected sources"
- Related: `002-002-serpapi-connector` - First connector implementation
