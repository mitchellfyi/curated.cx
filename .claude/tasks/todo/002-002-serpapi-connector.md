# Task: Implement SerpApi Ingestion Connector

## Metadata

| Field | Value |
|-------|-------|
| ID | `002-002-serpapi-connector` |
| Status | `todo` |
| Priority | `002` High |
| Created | `2025-01-23 00:05` |
| Started | |
| Completed | |
| Blocked By | `002-001-ingestion-storage-model` |
| Blocks | `002-003-categorisation-system` |

---

## Context

SerpApi is the first external data connector. It allows Site admins to define search queries that pull news, articles, and other content from Google search results.

Key requirements:
- Site admin can create/manage SerpApi query sources
- Background job executes queries and stores results
- Deduping prevents duplicate ContentItems across runs
- Strict rate limiting to avoid API cost surprises

---

## Acceptance Criteria

- [ ] SerpApi source type added to Source model
- [ ] Source config schema defined for SerpApi (query, location, language, etc.)
- [ ] Background job (SerpApiIngestionJob) processes sources
- [ ] Job creates ImportRun record with proper status tracking
- [ ] Results parsed and stored as ContentItems
- [ ] Deduping by canonical URL works across runs
- [ ] Rate limiting enforced per Site (configurable)
- [ ] Max items per run configurable
- [ ] Errors captured cleanly in ImportRun
- [ ] Admin UI for creating/editing SerpApi sources
- [ ] Manual "run now" button in admin
- [ ] Scheduler integration (recurring job)
- [ ] Tests mock HTTP calls to SerpApi
- [ ] Tests verify parsing and persistence
- [ ] `docs/connectors/serpapi.md` documents setup and behavior
- [ ] Quality gates pass
- [ ] Changes committed with task reference

---

## Plan

1. **Add SerpApi gem or HTTP client**
   - Evaluate serpapi gem vs direct HTTP
   - Add to Gemfile

2. **Define SerpApi source config schema**
   - query (required)
   - location, language, search_type
   - max_results_per_run
   - rate_limit_per_hour

3. **Create SerpApiIngestionJob**
   - Fetch results from SerpApi
   - Parse organic results
   - Create/update ContentItems
   - Track ImportRun status

4. **Implement rate limiting**
   - Use Redis or database counter
   - Per-Site limits
   - Configurable thresholds

5. **Add admin UI**
   - Source CRUD for SerpApi type
   - "Run Now" action
   - View ImportRun history

6. **Add scheduler**
   - Recurring job configuration
   - Cron-style scheduling per source

7. **Write tests**
   - Mock SerpApi responses
   - Test parsing of different result types
   - Test dedupe across runs
   - Test rate limit enforcement

8. **Write documentation**
   - `docs/connectors/serpapi.md`
   - Setup instructions
   - Configuration options
   - Expected behavior

---

## Work Log

(To be filled during implementation)

---

## Testing Evidence

(To be filled during implementation)

---

## Notes

- SerpApi has different endpoints (google, news, images) - start with google news
- Consider caching API responses for development/testing
- May want to add a "dry run" mode that doesn't persist

---

## Links

- Dependency: `002-001-ingestion-storage-model`
- SerpApi Docs: https://serpapi.com/search-api
- Mission: `MISSION.md` - Autonomy loop step 1 (Ingest)
