# SerpApi Connector

The SerpApi connector fetches news articles from Google News via SerpApi and stores them as ContentItems for curation.

## Setup

### Prerequisites

1. Sign up for a SerpApi account at https://serpapi.com
2. Obtain an API key from your SerpApi dashboard

### Creating a Source

Navigate to Admin > Sources and create a new source with kind `serp_api_google_news`.

## Configuration Options

| Option | Type | Required | Default | Description |
|--------|------|----------|---------|-------------|
| `api_key` | string | Yes | - | Your SerpApi API key |
| `query` | string | Yes | - | Search query for Google News |
| `location` | string | No | "United States" | Geographic location for search |
| `language` | string | No | "en" | Language code (e.g., "en", "es", "fr") |
| `max_results` | integer | No | 50 | Maximum items to import per run |
| `rate_limit_per_hour` | integer | No | 10 | Maximum API calls per hour |

### Example Configuration

```json
{
  "api_key": "your_serpapi_key",
  "query": "AI technology news",
  "location": "United States",
  "language": "en",
  "max_results": 50,
  "rate_limit_per_hour": 10
}
```

## Scheduling

Sources are processed automatically by the `ProcessDueSourcesJob`, which runs every 15 minutes. A source is considered "due for run" when:

1. It has never been run (`last_run_at` is nil), OR
2. More than 1 hour has passed since `last_run_at`

You can also trigger a manual run from the Admin UI using the "Run Now" button.

### Schedule Configuration

The `schedule` field accepts an `interval_seconds` value:

```json
{
  "interval_seconds": 3600
}
```

## Rate Limiting

Rate limiting prevents excessive API usage and cost overruns. The limiter:

1. Counts `ImportRun` records created in the last hour for the source
2. Blocks new runs if the count exceeds `rate_limit_per_hour`
3. Resets automatically as import runs age out of the 1-hour window

### Rate Limit Status

The Admin UI shows current rate limit status:
- Remaining requests in the current window
- Time until the oldest request expires

When rate-limited, the source status shows "rate_limited" and no ImportRun is created.

## Deduplication

ContentItems are deduplicated by canonical URL:

1. Raw URLs from SerpApi are canonicalized using `UrlCanonicaliser`
2. `ContentItem.find_or_initialize_by_canonical_url` looks up existing items
3. Existing items are updated; new items are created

This prevents duplicate entries when the same article appears in multiple runs.

## Import Tracking

Each run creates an `ImportRun` record with:

| Field | Description |
|-------|-------------|
| `status` | running, completed, failed |
| `started_at` | When the job started |
| `completed_at` | When the job finished |
| `items_created` | Count of new ContentItems |
| `items_updated` | Count of existing items updated |
| `items_failed` | Count of items that failed to save |
| `error_message` | Error details if status is failed |

View import history in the Admin > Sources > [Source] detail page.

## Error Handling

### Job-Level Errors

If the job fails (e.g., API error, network timeout):
- ImportRun is marked as `failed` with the error message
- Source status shows the error
- Job retries up to 3 times with exponential backoff

### Item-Level Errors

Individual item failures (e.g., invalid URL) are logged but don't fail the entire run:
- Failed items increment `items_failed` count
- Other items continue processing
- Warnings are logged for debugging

## Architecture

```
ProcessDueSourcesJob (every 15 min)
    |
    v
Source.enabled.due_for_run
    |
    v
SerpApiIngestionJob.perform_later(source_id)
    |
    +--> SerpApiRateLimiter.allow?
    |        |
    |        v (if blocked)
    |        return "rate_limited"
    |
    v (if allowed)
    ImportRun.create_for_source!
    |
    v
    fetch_from_serp_api (Net::HTTP)
    |
    v
    process_results (for each news item)
    |
    +--> UrlCanonicaliser.canonicalize(url)
    |
    +--> ContentItem.find_or_initialize_by_canonical_url
    |
    v
    ImportRun.mark_completed!
```

## Files

| File | Purpose |
|------|---------|
| `app/jobs/serp_api_ingestion_job.rb` | Main ingestion job |
| `app/services/serp_api_rate_limiter.rb` | Database-backed rate limiter |
| `app/jobs/process_due_sources_job.rb` | Scheduler that enqueues due sources |
| `app/controllers/admin/sources_controller.rb` | Admin CRUD + run_now |
| `app/policies/source_policy.rb` | Authorization policy |

## Testing

```bash
# Run all SerpApi-related specs
bundle exec rspec spec/jobs/serp_api_ingestion_job_spec.rb
bundle exec rspec spec/services/serp_api_rate_limiter_spec.rb
bundle exec rspec spec/jobs/process_due_sources_job_spec.rb
bundle exec rspec spec/requests/admin/sources_spec.rb
```

HTTP calls are mocked using the `stub_serp_api_response` helper in specs.
