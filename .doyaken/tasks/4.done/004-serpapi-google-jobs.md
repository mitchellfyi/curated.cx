# Add SerpAPI Google Jobs Engine

## Description

Create a new source type and job for ingesting job listings via SerpAPI's Google Jobs engine.

## Acceptance Criteria

- [ ] Add `serp_api_google_jobs` to Source kind enum
- [ ] Create SerpApiJobsIngestionJob
- [ ] Add to ProcessDueSourcesJob mapping
- [ ] Parse job listings into Listing model (type: job)
- [ ] Extract: title, company, location, salary_range, apply_url

## Technical Details

SerpAPI Google Jobs endpoint:
```
https://serpapi.com/search.json?engine=google_jobs&q=AI+engineer
```

Response structure:
```json
{
  "jobs_results": [
    {
      "title": "AI Engineer",
      "company_name": "TechCorp",
      "location": "San Francisco, CA",
      "description": "...",
      "detected_extensions": {
        "posted_at": "3 days ago",
        "salary": "$150,000 - $200,000"
      },
      "apply_options": [
        { "title": "Apply on LinkedIn", "link": "..." }
      ]
    }
  ]
}
```

## Priority

medium

## Labels

feature, ingestion, jobs
