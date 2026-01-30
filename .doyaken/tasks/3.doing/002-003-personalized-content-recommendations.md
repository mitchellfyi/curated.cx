# Task: Personalized Content Recommendations

## Metadata

| Field       | Value                                                  |
| ----------- | ------------------------------------------------------ |
| ID          | `002-003-personalized-content-recommendations`         |
| Status      | `todo`                                                 |
| Priority    | `002` High                                             |
| Created     | `2026-01-30 15:30`                                     |
| Started     |                                                        |
| Completed   |                                                        |
| Blocked By  |                                                        |
| Blocks      |                                                        |
| Assigned To | `worker-1` |
| Assigned At | `2026-01-30 17:22` |

---

## Context

Why does this task exist? What problem does it solve?

- **Industry Trend**: AI-powered personalization improves conversion rates by 202%. Netflix's recommendation engine drives 80% of viewing time. The recommendation engine market is at $12 billion in 2026.
- **Competitive Gap**: Ghost has a new discovery engine (Nov 2025). Substack's in-app discovery drove 32 million new subscribers in 3 months. Curated has no personalization beyond category browsing.
- **User Value**: Readers get generic feeds. Personalized recommendations increase engagement, time on site, and return visits.
- **RICE Score**: 225 (Reach: 1500, Impact: 2, Confidence: 75%, Effort: 1 person-week)

**Problem**: All users see the same content feed ranked by freshness and engagement. There's no personalization based on reading history, interests, or behavior.

**Solution**: A recommendation engine using collaborative filtering and content-based signals to personalize the feed for logged-in users.

---

## Acceptance Criteria

All must be checked before moving to done:

- [ ] Track user reading history (content item views)
- [ ] Track user interactions (upvotes, bookmarks, comments)
- [ ] ContentRecommendation service using reading signals
- [ ] "Recommended for you" section on homepage
- [ ] "Similar content" on content item pages
- [ ] "You might also like" in digest emails
- [ ] User interest preferences in profile settings
- [ ] Fallback to trending content for new/anonymous users
- [ ] Tests written and passing
- [ ] Quality gates pass
- [ ] Changes committed with task reference

---

## Plan

Step-by-step implementation approach:

1. **Step 1**: Create ContentView tracking
   - Files: `app/models/content_view.rb`, `db/migrate/xxx_create_content_views.rb`
   - Actions: user_id, content_item_id, viewed_at, duration (optional)

2. **Step 2**: Create UserInterest model
   - Files: `app/models/user_interest.rb`
   - Actions: Derived from views, votes, bookmarks; store category/taxonomy affinities

3. **Step 3**: Create RecommendationService
   - Files: `app/services/recommendation_service.rb`
   - Actions: Content-based filtering using taxonomy similarity, collaborative filtering using similar users

4. **Step 4**: Add recommendation endpoints
   - Files: `app/controllers/recommendations_controller.rb`
   - Actions: Personalized feed, similar content, for-you section

5. **Step 5**: Update homepage to show recommendations
   - Files: `app/views/tenant/homepages/`, `app/controllers/tenant/homepages_controller.rb`
   - Actions: Add "For You" section for logged-in users

6. **Step 6**: Add to content item pages
   - Files: `app/views/content_items/show.html.erb`
   - Actions: "Similar Content" section using content similarity

7. **Step 7**: Add to digest emails
   - Files: Email templates, digest service
   - Actions: Include personalized recommendations in weekly/daily emails

8. **Step 8**: Write tests
   - Files: `spec/services/recommendation_service_spec.rb`
   - Coverage: Cold start, personalized, similar content

---

## Work Log

_No work started yet._

---

## Testing Evidence

_No tests run yet._

---

## Notes

- Start simple with category/taxonomy affinity, expand to ML later
- Consider privacy - don't expose reading history to other users
- Use existing Vote, Bookmark, Comment models for interaction signals
- Cache recommendations with short TTL (1 hour)
- A/B test recommendation algorithms

---

## Links

- Research: Netflix recommendation engine, Ghost discovery engine
- Related: Vote, Bookmark, FeedRankingService
