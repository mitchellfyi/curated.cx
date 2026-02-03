# Seed Content Sources for Each Tenant

## Description

Create Source records for each tenant (ainews, construction, dayz) with SerpAPI configuration for automated content ingestion.

## Acceptance Criteria

- [ ] Create SerpAPI Google News source for ainews.cx
- [ ] Create SerpAPI Google News source for construction.cx  
- [ ] Create SerpAPI Google News source for dayz.cx
- [ ] Configure appropriate search queries per vertical
- [ ] Set schedule intervals (e.g., every 1-2 hours)
- [ ] Enable editorialisation for AI summaries

## Source Configuration Template

```ruby
Source.create!(
  site: site,
  tenant: tenant,
  name: "Google News - AI",
  kind: :serp_api_google_news,
  enabled: true,
  config: {
    api_key: ENV["SERPAPI_KEY"],
    query: "artificial intelligence OR machine learning",
    location: "United States",
    language: "en",
    max_results: 50,
    editorialise: true
  },
  schedule: {
    interval_seconds: 3600  # 1 hour
  }
)
```

## Queries by Tenant

**ainews.cx:**
- "artificial intelligence news"
- "machine learning"
- "AI tools"
- "ChatGPT OR Claude OR Gemini"

**construction.cx:**
- "construction industry news"
- "building materials"
- "construction technology"

**dayz.cx:**
- "DayZ game news"
- "DayZ update"
- "DayZ mods"

## Priority

high

## Labels

feature, ingestion, setup
