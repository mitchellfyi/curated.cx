# Task: Add Missing Background Job Specs

## Metadata

| Field | Value |
|-------|-------|
| ID | `001-006-add-job-specs` |
| Status | `todo` |
| Priority | `001` Critical |
| Created | `2026-01-23 01:00` |
| Started | |
| Completed | |
| Blocked By | |
| Blocks | |
| Assigned To | |
| Assigned At | |

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

1. **FetchRssJob Specs**
   - File: `spec/jobs/fetch_rss_job_spec.rb`
   - Test: Fetches RSS, creates ContentItems
   - Test: Handles invalid RSS gracefully
   - Test: Updates Source run status
   - Mock: HTTP requests with WebMock

2. **FetchSerpApiNewsJob Specs**
   - File: `spec/jobs/fetch_serp_api_news_job_spec.rb`
   - Test: Calls SerpAPI, creates ContentItems
   - Test: Handles API errors
   - Test: Rate limit handling
   - Mock: SerpAPI responses

3. **UpsertListingsJob Specs**
   - File: `spec/jobs/upsert_listings_job_spec.rb`
   - Test: Creates new listings from ContentItems
   - Test: Deduplicates existing listings (by URL)
   - Test: Assigns correct tenant/site/category
   - Test: Idempotency

4. **ScrapeMetadataJob Specs**
   - File: `spec/jobs/scrape_metadata_job_spec.rb`
   - Test: Extracts title, description, image
   - Test: Handles missing metadata gracefully
   - Test: Handles timeout/network errors
   - Mock: HTTP with sample HTML responses

5. **Test Infrastructure**
   - Add job testing helpers if needed
   - Configure test queue adapter

---

## Work Log

(To be filled during execution)

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
