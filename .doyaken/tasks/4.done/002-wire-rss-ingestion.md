# Wire RSS Ingestion to ProcessDueSourcesJob

## Description

Add RSS source type to the ProcessDueSourcesJob mapping so RSS sources are processed on schedule.

## Acceptance Criteria

- [ ] Add `"rss" => FetchRssJob` to JOB_MAPPING in ProcessDueSourcesJob
- [ ] Verify FetchRssJob works correctly with Source model
- [ ] Add test coverage for RSS source processing

## Technical Details

File: `app/jobs/process_due_sources_job.rb`

```ruby
JOB_MAPPING = {
  "serp_api_google_news" => SerpApiIngestionJob,
  "rss" => FetchRssJob  # Add this
}.freeze
```

## Priority

high

## Labels

feature, ingestion
