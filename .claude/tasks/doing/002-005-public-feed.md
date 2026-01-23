# Task: Implement Public Feed for Sites

## Metadata

| Field | Value |
|-------|-------|
| ID | `002-005-public-feed` |
| Status | `todo` |
| Priority | `002` High |
| Created | `2025-01-23 00:05` |
| Started | |
| Completed | |
| Blocked By | `002-004-ai-editorialisation` |
| Blocks | `002-006-community-primitives` |

---

## Context

Each Site needs a public-facing feed showing curated content. The homepage displays:
- Ranked feed of ContentItems
- Filters by tag and content type
- "Top this week" view

Initial ranking uses freshness decay, source quality weight, and engagement signals.

---

## Acceptance Criteria

- [ ] Site homepage shows ranked content feed
- [ ] Pagination working (infinite scroll or pages)
- [ ] Filter by tag (from taxonomy)
- [ ] Filter by content type
- [ ] "Top this week" view available
- [ ] "Latest" view available
- [ ] Ranking algorithm implemented:
  - [ ] Freshness decay factor
  - [ ] Source quality weight
  - [ ] Engagement signals (upvotes, comments)
- [ ] Feed performance optimized (proper indexes, caching)
- [ ] SEO meta tags on feed pages
- [ ] Mobile responsive design
- [ ] RSS feed endpoint
- [ ] Tests cover ranking order with fixtures
- [ ] `docs/ranking.md` documents algorithm
- [ ] Quality gates pass
- [ ] Changes committed with task reference

---

## Plan

1. **Create FeedService**
   - Query ContentItems with ranking
   - Apply filters (tag, type, time range)
   - Return paginated results

2. **Implement ranking algorithm**
   ```ruby
   score = (
     freshness_score * freshness_weight +
     source_quality * quality_weight +
     engagement_score * engagement_weight
   )
   ```
   - Freshness: exponential decay from published_at
   - Source quality: configurable per Source
   - Engagement: upvotes + (comments * 0.5)

3. **Build feed controller/views**
   - Index action with filters
   - Show action for single item
   - Partials for content cards

4. **Add filter UI**
   - Tag pills/dropdown
   - Content type tabs
   - Time range selector

5. **Implement "Top this week"**
   - Filter by last 7 days
   - Sort by engagement score primarily

6. **Add RSS endpoint**
   - Standard RSS 2.0 format
   - Include summary and link

7. **Optimize performance**
   - Database indexes for ranking queries
   - Consider materialized view for hot content
   - Fragment caching for cards

8. **Write tests**
   - Ranking order verification
   - Filter combinations
   - Edge cases (no content, single item)

9. **Write documentation**
   - `docs/ranking.md`
   - Algorithm explanation
   - Tuning guidance

---

## Work Log

(To be filled during implementation)

---

## Testing Evidence

(To be filled during implementation)

---

## Notes

- Start with simple linear ranking, can evolve to ML later
- Consider A/B testing infrastructure for ranking experiments
- May want personalization later (based on user history)
- RSS feed is important for power users

---

## Links

- Dependency: `002-004-ai-editorialisation`
- Mission: `MISSION.md` - "Rank: score items by relevance"
