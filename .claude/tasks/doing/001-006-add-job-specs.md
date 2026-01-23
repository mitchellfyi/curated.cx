# Task: Add Missing Background Job Specs

## Metadata

| Field | Value |
|-------|-------|
| ID | `001-006-add-job-specs` |
| Status | `doing` |
| Priority | `001` Critical |
| Created | `2026-01-23 01:00` |
| Started | `2026-01-23 02:10` |
| Completed | |
| Blocked By | |
| Blocks | |
| Assigned To | `worker-3` |
| Assigned At | `2026-01-23 02:10` |

---

## Context

Background jobs are critical to the autonomy loop (ingestion, normalization, publishing) but have **no test coverage**:

| Job | Lines | Specs |
|-----|-------|-------|
| `FetchRssJob` | ~100 | ❌ None |
| `FetchSerpApiNewsJob` | ~80 | ❌ None |
| `UpsertListingsJob` | ~60 | ❌ None |
| `ScrapeMetadataJob` | ~120 | ❌ None |
| `HeartbeatJob` | ~30 | ⚠️ Minimal |

**Risk**: Jobs can silently break with no test safety net. The ingestion pipeline is the core value prop.

---

## Acceptance Criteria

- [ ] Add `spec/jobs/fetch_rss_job_spec.rb` with comprehensive tests
- [ ] Add `spec/jobs/fetch_serp_api_news_job_spec.rb`
- [ ] Add `spec/jobs/upsert_listings_job_spec.rb`
- [ ] Add `spec/jobs/scrape_metadata_job_spec.rb`
- [ ] Test happy path for each job
- [ ] Test error handling and retry behavior
- [ ] Test idempotency (running twice doesn't duplicate)
- [ ] Mock external APIs (RSS feeds, SerpAPI, HTTP)
- [ ] Quality gates pass

---

## Plan

### Implementation Plan (Generated 2026-01-23 02:15, Updated 2026-01-23 02:36)

#### Gap Analysis (Updated 2026-01-23 02:36)
| Criterion | Status | Gap |
|-----------|--------|-----|
| Add `spec/jobs/fetch_rss_job_spec.rb` | ✅ Done | File exists (162 lines, 13 tests) |
| Add `spec/jobs/fetch_serp_api_news_job_spec.rb` | ✅ Done | File exists (173 lines, 15 tests) |
| Add `spec/jobs/upsert_listings_job_spec.rb` | ✅ Done | File exists (196 lines, 19 tests) |
| Add `spec/jobs/scrape_metadata_job_spec.rb` | ✅ Done | File exists (260 lines, 20 tests) |
| Test happy path for each job | ✅ Done | All 4 jobs have happy path tests |
| Test error handling and retry behavior | ✅ Done | Error + retry tests in all specs |
| Test idempotency | ✅ Done | UpsertListingsJob has idempotency tests |
| Mock external APIs | ✅ Done | WebMock configured, fixtures created |
| Quality gates pass | ⏳ Pending | Run `bundle exec rspec spec/jobs/` to verify |

**Implementation Status**: COMPLETE - all code written and committed. Only verification remaining.

#### Pre-Implementation: Add WebMock

**CRITICAL**: WebMock is NOT in the Gemfile. Must add it first.

1. `Gemfile` - Add to `:test` group:
   ```ruby
   gem "webmock", "~> 3.23"
   ```

2. `spec/support/webmock.rb` - Create new file:
   - Require webmock/rspec
   - Disable external HTTP connections in tests
   - Configure allowed hosts if needed (localhost)

3. Run `bundle install`

#### Files to Create

##### 1. `spec/support/webmock.rb`
Purpose: Configure WebMock for HTTP stubbing

```ruby
require 'webmock/rspec'
WebMock.disable_net_connect!(allow_localhost: true)
```

##### 2. `spec/support/job_helpers.rb`
Purpose: Shared helpers for job specs

- Include TenantTestHelpers for job type specs
- Add helper to create source with feed URL
- Add helper to stub RSS feed responses
- Add helper to stub SerpAPI responses
- Add helper to stub MetaInspector responses

##### 3. `spec/jobs/fetch_rss_job_spec.rb` (~100 lines)
**Job Analysis (app/jobs/fetch_rss_job.rb:105 lines)**:
- Queue: `:ingestion`
- Retry: `retry_on StandardError, wait: :exponentially_longer, attempts: 3`
- Takes: `source_id`
- External calls: HTTP GET to RSS feed URL, Feedjira parsing
- Side effects: Creates UpsertListingsJob for each URL, updates source.last_run_at/last_status

**Tests needed**:
1. Happy path: Valid RSS → enqueues UpsertListingsJobs for each entry URL
2. Skips disabled source (updates status to "skipped")
3. Skips non-RSS source (updates status to "skipped")
4. Error: Missing feed URL in config → raises error
5. Error: Feed fetch HTTP error (4xx/5xx) → raises, source status "error: ..."
6. Error: Invalid RSS XML → raises, source status "error: ..."
7. Retry behavior: retries on StandardError
8. Tenant context: Sets Current.tenant/site during execution, clears after
9. Creates category if doesn't exist

**Mocking strategy**:
- WebMock for HTTP requests to feed URL
- Use `have_enqueued_job(UpsertListingsJob)` matcher for job chaining

##### 4. `spec/jobs/fetch_serp_api_news_job_spec.rb` (~100 lines)
**Job Analysis (app/jobs/fetch_serp_api_news_job.rb:106 lines)**:
- Queue: `:ingestion`
- Retry: `retry_on StandardError, wait: :exponentially_longer, attempts: 3`
- Takes: `source_id`
- External calls: HTTP GET to serpapi.com/search.json
- Side effects: Creates UpsertListingsJob for each URL, updates source status

**Tests needed**:
1. Happy path: Valid SerpAPI response → enqueues UpsertListingsJobs
2. Skips disabled source
3. Skips non-serp_api_google_news source
4. Error: Missing API key → raises
5. Error: SerpAPI HTTP error → raises, source status "error: ..."
6. Handles empty news_results array gracefully
7. Uses config query, location, language params
8. Retry behavior
9. Tenant context management

**Mocking strategy**:
- WebMock for serpapi.com requests
- Return JSON with news_results array

##### 5. `spec/jobs/upsert_listings_job_spec.rb` (~120 lines)
**Job Analysis (app/jobs/upsert_listings_job.rb:93 lines)**:
- Queue: `:ingestion`
- Retry: `retry_on ActiveRecord::RecordNotUnique` (5 attempts), `retry_on StandardError` (3 attempts)
- Takes: `tenant_id, category_id, url_raw, source_id: nil`
- External calls: None (but enqueues ScrapeMetadataJob)
- Side effects: Creates Listing, enqueues ScrapeMetadataJob

**Tests needed**:
1. Happy path: Creates new listing with correct attributes
2. Idempotency: Same URL → no duplicate listing created, returns existing
3. URL canonicalization: Strips tracking params, normalizes URL
4. Invalid URL → logs warning, returns nil (no error raised)
5. Existing listing → updates source if provided
6. Race condition handling: RecordNotUnique → retries and finds existing
7. Enqueues ScrapeMetadataJob after successful create
8. Does NOT enqueue ScrapeMetadataJob for existing listing
9. Tenant/site context management
10. Category must belong to site validation

**Mocking strategy**:
- No HTTP mocking needed
- Use `have_enqueued_job(ScrapeMetadataJob)` for job chaining

##### 6. `spec/jobs/scrape_metadata_job_spec.rb` (~100 lines)
**Job Analysis (app/jobs/scrape_metadata_job.rb:114 lines)**:
- Queue: `:scraping`
- Retry: `retry_on StandardError, wait: :exponentially_longer, attempts: 3`
- Takes: `listing_id`
- External calls: MetaInspector (HTTP fetch + HTML parsing)
- Side effects: Updates listing with scraped metadata

**Tests needed**:
1. Happy path: Updates listing with title, description, image_url, site_name
2. Extracts published_at from meta tags (article:published_time, og:published_time)
3. Extracts published_at from JSON-LD datePublished
4. Handles missing metadata gracefully (keeps existing values)
5. Error: MetaInspector timeout → logs warning, doesn't raise (job doesn't block queue)
6. Error: MetaInspector request error → logs warning, doesn't raise
7. Body HTML and text extraction
8. Tenant context management

**Mocking strategy**:
- Mock MetaInspector.new to return a mock page object
- OR stub the HTTP requests MetaInspector makes

#### Test Fixtures/Helpers Needed

1. **RSS Feed fixture** (`spec/fixtures/files/sample_feed.xml`):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Sample Feed</title>
    <item>
      <title>Article 1</title>
      <link>https://example.com/article-1</link>
    </item>
    <item>
      <title>Article 2</title>
      <link>https://example.com/article-2</link>
    </item>
  </channel>
</rss>
```

2. **SerpAPI response fixture** (`spec/fixtures/files/serp_api_news.json`):
```json
{
  "news_results": [
    {"title": "News 1", "link": "https://news.example.com/1"},
    {"title": "News 2", "link": "https://news.example.com/2"}
  ]
}
```

3. **HTML page fixture** (`spec/fixtures/files/sample_page.html`):
```html
<html>
<head>
  <title>Page Title</title>
  <meta name="description" content="Page description">
  <meta property="og:image" content="https://example.com/image.jpg">
  <meta property="article:published_time" content="2026-01-15T10:00:00Z">
</head>
<body>Page content</body>
</html>
```

#### Implementation Order

1. Add WebMock to Gemfile, run bundle install
2. Create `spec/support/webmock.rb`
3. Create `spec/support/job_helpers.rb` (shared setup)
4. Create RSS feed fixture
5. Create `spec/jobs/fetch_rss_job_spec.rb`
6. Run specs, fix any issues
7. Create SerpAPI fixture
8. Create `spec/jobs/fetch_serp_api_news_job_spec.rb`
9. Run specs, fix any issues
10. Create `spec/jobs/upsert_listings_job_spec.rb`
11. Run specs, fix any issues
12. Create HTML fixture
13. Create `spec/jobs/scrape_metadata_job_spec.rb`
14. Run all job specs together
15. Run full quality gates

#### Docs to Update
- [ ] None required - internal test files only

#### Risk Assessment
- **Low risk**: Greenfield specs, no existing behavior to break
- **Medium complexity**: HTTP mocking setup for multiple external services
- **Dependencies**: Needs WebMock gem added first

---

## Work Log

### 2026-01-23 02:42 - TEST Phase

**Fix Applied:**
- `spec/jobs/scrape_metadata_job_spec.rb`: Fixed "clears context even when error occurs" test
  - Added begin/rescue block since job re-raises StandardError after ensure block
  - Test now properly expects error re-raise behavior
  - Commit: `e5501a0`

**Quality Gates Status:**
- RuboCop: ✅ Pass - `6 files inspected, no offenses detected`
- Brakeman: ✅ Pass - `0 security warnings`
- Ruby Syntax: ✅ Pass - All 4 job specs have valid Ruby syntax
- RSpec: ⏸️ BLOCKED - PostgreSQL requires manual permission

**PostgreSQL Blocker:**
```
FATAL: Postgres.app failed to verify "trust" authentication
DETAIL: You did not confirm the permission dialog
```
**Action Required**: User must open Postgres.app and confirm the permission dialog.

**Test File Summary:**
- `spec/jobs/fetch_rss_job_spec.rb` - 206 lines, 13 test cases
- `spec/jobs/fetch_serp_api_news_job_spec.rb` - 218 lines, 15 test cases
- `spec/jobs/upsert_listings_job_spec.rb` - 223 lines, 19 test cases
- `spec/jobs/scrape_metadata_job_spec.rb` - 320 lines, 20 test cases

**Total: 67 test cases** covering:
- Happy path for all 4 jobs
- Error handling and retry behavior
- Idempotency (UpsertListingsJob)
- External API mocking (WebMock configured)
- Tenant context management
- Queue configuration

**All code verified syntactically correct and style-compliant.**

---

### 2026-01-23 02:37 - Implementation Phase (Verification)

**Status**: Implementation already complete from previous session

**Quality Check Results:**
- RuboCop: ✅ Pass - `6 files inspected, no offenses detected`
- Ruby Syntax: ✅ Pass - All 4 job specs have valid syntax
- Files verified present:
  - `spec/jobs/fetch_rss_job_spec.rb` (206 lines)
  - `spec/jobs/fetch_serp_api_news_job_spec.rb` (218 lines)
  - `spec/jobs/upsert_listings_job_spec.rb` (223 lines)
  - `spec/jobs/scrape_metadata_job_spec.rb` (315 lines)
- Fixtures verified present:
  - `spec/fixtures/files/sample_feed.xml` (988 bytes)
  - `spec/fixtures/files/serp_api_news.json` (872 bytes)
  - `spec/fixtures/files/sample_page.html` (1333 bytes)

**Database Issue**: PostgreSQL authentication still blocked (Postgres.app requires manual permission dialog confirmation)

**Implementation complete**: No additional code changes needed

**Next**: TEST phase to run full test suite once DB is available

---

### 2026-01-23 02:36 - Plan Phase (Verification)

**Gap Analysis Review:**
Verified all implementation files exist:
- `spec/jobs/fetch_rss_job_spec.rb` ✅
- `spec/jobs/fetch_serp_api_news_job_spec.rb` ✅
- `spec/jobs/upsert_listings_job_spec.rb` ✅
- `spec/jobs/scrape_metadata_job_spec.rb` ✅
- `spec/support/webmock.rb` ✅
- `spec/support/job_helpers.rb` ✅
- `spec/fixtures/files/sample_feed.xml` ✅
- `spec/fixtures/files/serp_api_news.json` ✅
- `spec/fixtures/files/sample_page.html` ✅

**Updated Gap Analysis** in Plan section to reflect current state (all criteria DONE except quality gates verification).

**Next Phase**: TEST - Run `bundle exec rspec spec/jobs/` to verify all tests pass.

---

### 2026-01-23 02:35 - Triage (Resume)

- **Dependencies**: ✅ None - `Blocked By` field is empty
- **Task clarity**: ✅ Clear - all acceptance criteria are specific and testable
- **Implementation status**: ✅ Complete - all 4 spec files + support files exist
- **Ready to proceed**: ✅ Yes - need to verify tests pass

**Current blocker**: PostgreSQL authentication issue from previous session
**Next action**: Attempt to run tests; if DB still blocked, verify code quality statically

---

### 2026-01-23 02:27 - Documentation Sync

**Docs updated:**
- `doc/README.md` - Fixed duplicate quality gate entries (lines 77-86 were duplicated)

**Annotations:**
- Model annotations: ⏸️ BLOCKED - PostgreSQL authentication issue prevents running `annotaterb models`

**Consistency checks:**
- [x] Code matches docs (no new endpoints or patterns introduced)
- [x] No broken links in markdown files
- [ ] Schema annotations current (blocked by DB)

**Task Documentation:**
- Testing Evidence section: Documented in Work Log entries
- Notes section: Complete with testing best practices
- Links section: Complete with all relevant files

**Files verified:**
- `spec/jobs/fetch_rss_job_spec.rb` (6,396 bytes)
- `spec/jobs/fetch_serp_api_news_job_spec.rb` (6,574 bytes)
- `spec/jobs/upsert_listings_job_spec.rb` (7,816 bytes)
- `spec/jobs/scrape_metadata_job_spec.rb` (10,004 bytes)

---

### 2026-01-23 02:24 - Testing Phase (DB Unavailable)

**Quality Gates Status:**
- RuboCop: ✅ Pass (6 job spec files, no offenses)
- Brakeman: ✅ Pass (0 security warnings)
- Ruby Syntax: ✅ Pass (all 4 job specs valid Ruby)
- RSpec: ⏸️ BLOCKED - PostgreSQL authentication issue

**Issue:** Postgres.app requires manual permission confirmation via the app GUI. Error:
```
FATAL: Postgres.app failed to verify "trust" authentication
DETAIL: You did not confirm the permission dialog
```

**Spec Fixes Applied:**
- `scrape_metadata_job_spec.rb`: Fixed error handling tests to match actual job behavior
  - Job retries on `ExternalServiceError`, not `StandardError`
  - Job re-raises errors (doesn't swallow them)
  - Timeout/Request errors are wrapped in `ExternalServiceError`

**Verification Complete:**
- All spec files validated as correct Ruby syntax
- All spec files pass RuboCop style checks
- All fixtures match expected test data
- Factory traits properly configured
- Test helpers properly set up

**Next Steps:**
1. User needs to confirm Postgres.app permission dialog
2. Run `bundle exec rspec spec/jobs/` to verify all tests pass
3. Run `./bin/quality` for full quality gates

---

### 2026-01-23 02:30 - Implementation Complete

**Commits:**
1. `539b70d` - test: Add WebMock and job test infrastructure
2. `4ece161` - test: Add comprehensive specs for background jobs

**Files Created:**
- `Gemfile` - Added `gem "webmock", "~> 3.23"` to test group
- `spec/support/webmock.rb` - WebMock configuration
- `spec/support/job_helpers.rb` - Job-specific test helpers
- `spec/fixtures/files/sample_feed.xml` - RSS feed fixture (3 entries)
- `spec/fixtures/files/serp_api_news.json` - SerpAPI response fixture (3 results)
- `spec/fixtures/files/sample_page.html` - HTML page with metadata for scraping
- `spec/jobs/fetch_rss_job_spec.rb` - 162 lines, 13 test cases
- `spec/jobs/fetch_serp_api_news_job_spec.rb` - 173 lines, 15 test cases
- `spec/jobs/upsert_listings_job_spec.rb` - 196 lines, 19 test cases
- `spec/jobs/scrape_metadata_job_spec.rb` - 260 lines, 20 test cases

**Test Coverage Summary:**
- FetchRssJob: happy path, disabled source, wrong type, missing URL, HTTP errors, invalid XML, tenant context, existing category, retry behavior
- FetchSerpApiNewsJob: happy path, disabled source, wrong type, missing API key, HTTP errors, empty results, config params, tenant context, retry behavior
- UpsertListingsJob: happy path, idempotency, URL normalization, invalid URL, validation errors, no source, tenant context, race conditions, retry behavior
- ScrapeMetadataJob: happy path, published_at extraction (3 sources), missing metadata, timeout/request errors, non-raising behavior, tenant context, MetaInspector config, retry behavior

**Quality Check:** RuboCop passed on all files

**Note:** Database connection issue prevented running tests locally (PostgreSQL authentication issue), but code is syntactically correct and follows established patterns.

---

### 2026-01-23 02:15 - Planning Complete

**Gap Analysis Summary:**
- All 4 spec files are greenfield (do not exist yet)
- WebMock gem is NOT in Gemfile - must be added first
- Existing job spec patterns in `heartbeat_job_spec.rb` and `application_job_spec.rb` provide good templates
- TenantTestHelpers available in `spec/support/tenant_helpers.rb` - will need to include for job specs
- Source factory has `:rss` and `:serp_api_google_news` traits ready to use
- Listing factory has all necessary attributes

**Key Findings:**
1. Jobs make HTTP calls via Net::HTTP directly (FetchRssJob, FetchSerpApiNewsJob)
2. ScrapeMetadataJob uses MetaInspector gem (wrapper around HTTP)
3. UpsertListingsJob is pure database operation + job chaining
4. All jobs set Current.tenant/site context and clear it in ensure block
5. All jobs have retry behavior configured

**Pre-requisite:** Must add `gem "webmock"` to Gemfile and create support file before writing specs

**Files analyzed:**
- `app/jobs/fetch_rss_job.rb` (105 lines) - uses Feedjira for RSS parsing
- `app/jobs/fetch_serp_api_news_job.rb` (106 lines) - calls serpapi.com
- `app/jobs/upsert_listings_job.rb` (93 lines) - creates listings, handles race conditions
- `app/jobs/scrape_metadata_job.rb` (114 lines) - uses MetaInspector
- `spec/jobs/heartbeat_job_spec.rb` - reference for job spec patterns
- `spec/support/tenant_helpers.rb` - reusable tenant context helpers

---

### 2026-01-23 02:10 - Triage Complete

- **Dependencies**: ✅ None - `Blocked By` field is empty
- **Task clarity**: ✅ Clear - specific job files listed, acceptance criteria are testable
- **Ready to proceed**: ✅ Yes

**Verification Notes:**
- All 4 target job files exist and are substantive:
  - `fetch_rss_job.rb` (105 lines)
  - `fetch_serp_api_news_job.rb` (106 lines)
  - `upsert_listings_job.rb` (93 lines)
  - `scrape_metadata_job.rb` (114 lines)
- Only 2 job spec files exist currently (`heartbeat_job_spec.rb`, `application_job_spec.rb`)
- None of the 4 target spec files exist yet - this is greenfield work
- Acceptance criteria are specific and measurable
- Plan is detailed and actionable

---

## Notes

Job testing best practices:
- Use `perform_now` for synchronous testing
- Mock all external HTTP with WebMock/VCR
- Test both `perform` and `perform_later` (enqueueing)
- Test retry behavior with `assert_performed_jobs`

RSpec helpers:
```ruby
RSpec.describe FetchRssJob, type: :job do
  include ActiveJob::TestHelper

  it "fetches and creates content items" do
    stub_request(:get, source.url).to_return(body: rss_fixture)
    expect { described_class.perform_now(source) }
      .to change(ContentItem, :count).by(10)
  end
end
```

---

## Links

- File: `app/jobs/fetch_rss_job.rb`
- File: `app/jobs/fetch_serp_api_news_job.rb`
- File: `app/jobs/upsert_listings_job.rb`
- File: `app/jobs/scrape_metadata_job.rb`
- Gem: https://github.com/bblimke/webmock
