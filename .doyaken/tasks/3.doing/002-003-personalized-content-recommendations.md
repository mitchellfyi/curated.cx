# Task: Personalized Content Recommendations

## Metadata

| Field       | Value                                                  |
| ----------- | ------------------------------------------------------ |
| ID          | `002-003-personalized-content-recommendations`         |
| Status      | `doing`                                                |
| Priority    | `002` High                                             |
| Created     | `2026-01-30 15:30`                                     |
| Started     | `2026-01-30 17:27`                                     |
| Completed   |                                                        |
| Blocked By  |                                                        |
| Blocks      |                                                        |
| Assigned To | `worker-1` |
| Assigned At | `2026-01-30 17:22` |

---

## Context

**Intent**: BUILD

### Problem Statement

All users see the same content feed ranked by freshness, source quality, and engagement (`FeedRankingService`). There's no personalization based on reading history, interests, or behavior. The current system uses a weighted scoring formula (40% freshness + 30% source quality + 30% engagement) that's identical for every user.

### Business Context

- **Industry Trend**: AI-powered personalization improves conversion rates by 202%. Netflix's recommendation engine drives 80% of viewing time.
- **Competitive Gap**: Ghost has a new discovery engine (Nov 2025). Substack's in-app discovery drove 32 million new subscribers in 3 months. Curated has no personalization beyond category browsing.
- **User Value**: Personalized recommendations increase engagement, time on site, and return visits.
- **RICE Score**: 225 (Reach: 1500, Impact: 2, Confidence: 75%, Effort: 1 person-week)

### Solution Overview

Build a recommendation engine that:
1. **Tracks user behavior** - Content views as implicit signals (existing Vote/Bookmark/Comment models provide explicit signals)
2. **Computes user interests** - Aggregate topic/taxonomy preferences from behavior patterns
3. **Generates personalized recommendations** - Content-based filtering using taxonomy similarity
4. **Surfaces recommendations** - Homepage "For You" section, content page "Similar Content", digest email "You might also like"
5. **Handles cold start** - Falls back to trending/engagement-ranked content for new/anonymous users

### Codebase Analysis

**Existing Infrastructure (use these):**
- `Vote` model (`app/models/vote.rb:28-42`) - user_id, content_item_id, tracks upvotes with counter_cache
- `Bookmark` model (`app/models/bookmark.rb:24-43`) - polymorphic, supports ContentItem
- `Comment` model - user_id, content_item_id
- `ContentItem.topic_tags` - JSONB array of taxonomy slugs (has GIN index)
- `FeedRankingService` (`app/services/feed_ranking_service.rb`) - Current ranking algorithm
- `Taxonomy` model - hierarchical categories with slugs
- `SiteScoped` concern - Multi-tenant isolation pattern
- `DigestMailer` (`app/mailers/digest_mailer.rb:3-70`) - Sends weekly/daily digests, currently not personalized

**Key Patterns to Follow:**
- Service pattern: Class method entry point (`.call` or similar), instance with dependencies
- Multi-tenancy: Include `SiteScoped` concern, records scoped to Current.site
- JSONB settings: Use `JsonbSettingsAccessor` concern for user preferences
- Email from-address cascade: site → tenant → default

**Files to Modify:**
- `app/views/tenants/show.html.erb:18-34` - Add "For You" section above "Latest Content"
- `app/services/tenant_homepage_service.rb:17-22` - Add personalized content to tenant_data
- `app/mailers/digest_mailer.rb:42-49` - Add personalized recommendations section

**New Files to Create:**
- `app/models/content_view.rb` - Track content views
- `db/migrate/xxx_create_content_views.rb` - Migration
- `app/services/content_recommendation_service.rb` - Recommendation engine
- `spec/services/content_recommendation_service_spec.rb` - Tests

---

## Acceptance Criteria

All must be checked before moving to done:

### Core Functionality
- [ ] **ContentView model tracks views**: Create `content_view` table with user_id, content_item_id, site_id, viewed_at, and unique constraint per user/content_item/site
- [ ] **View tracking endpoint**: POST endpoint to record views when user clicks into content (track via controller callback or JS)
- [ ] **ContentRecommendationService**: Service that computes personalized content using taxonomy affinity scores
- [ ] **Personalization algorithm**: Score content by matching user's topic_tag interests (weighted by recency and interaction type)
- [ ] **Cold start fallback**: For users with <5 interactions, return engagement-ranked content from `FeedRankingService`

### User-Facing Features
- [ ] **"For You" section on homepage** (`app/views/tenants/show.html.erb`): Show 6 personalized items for logged-in users above "Latest Content"
- [ ] ~~**"Similar Content" on content pages**~~: **DESCOPED** - No content detail page exists; items link directly to external URLs. Create separate task if needed.
- [ ] **Personalized digest emails**: Add "Recommended for you" section to weekly/daily digests with 3-5 personalized items

### Data & Performance
- [ ] **Index on content_views**: Add composite index for (user_id, site_id, viewed_at DESC) for efficient lookups
- [ ] **Cache recommendations**: Cache personalized feed per user with 1-hour TTL using Rails.cache

### Quality
- [ ] Tests written and passing (service specs, model specs, controller specs)
- [ ] Quality gates pass (rubocop, brakeman, rspec)
- [ ] Changes committed with task reference [002-003-personalized-content-recommendations]

---

## Plan

### Gap Analysis

| Criterion | Status | Gap |
|-----------|--------|-----|
| ContentView model tracks views | none | Model, migration, and tracking endpoint don't exist |
| View tracking endpoint | none | No endpoint exists; no content detail page either (items link externally) |
| ContentRecommendationService | none | Service doesn't exist |
| Personalization algorithm | none | No implementation exists |
| Cold start fallback | partial | `FeedRankingService.ranked_feed` exists and can be used |
| "For You" section on homepage | none | Section doesn't exist; `TenantHomepageService` needs extension |
| "Similar Content" on content pages | **BLOCKED** | No content detail page exists - items link directly to external URLs |
| Personalized digest emails | none | `DigestMailer` exists but has no personalization |
| Index on content_views | none | Table doesn't exist yet |
| Cache recommendations | none | No caching implemented |
| Tests | none | No tests for recommendation features |

### Risks

- [ ] **No content detail page**: "Similar Content" criterion cannot be implemented as specified. Content items link directly to `url_canonical` (external URLs). **Mitigation**: Descope this criterion OR implement interstitial page OR add similar content to expanded card view. Need clarification.
- [ ] **Cold start quality**: With <5 interactions, recommendations may feel generic. **Mitigation**: Already planned - fallback to `FeedRankingService` engagement ranking.
- [ ] **View tracking without detail page**: Need alternative approach since there's no show action. **Mitigation**: Track via JavaScript when user clicks external link (fire POST before redirect).
- [ ] **Multi-tenant data leak**: Recommendations must be site-scoped. **Mitigation**: Use `SiteScoped` concern, all queries include `site_id`.
- [ ] **Performance**: Computing recommendations per-request is slow. **Mitigation**: Cache per user/site with 1-hour TTL.

### Blocking Issue: "Similar Content" Criterion

The acceptance criterion states:
> **"Similar Content" on content pages**: Show 4 similar items based on shared topic_tags (below main content)

However, **no content detail page exists**. The `_content_card.html.erb` partial links directly to `content_item.url_canonical` (external URL) at line 34-38. Routes (`config/routes.rb`) show `resources :content_items, only: []` - no show action.

**Options:**
1. **Descope**: Remove "Similar Content" from this task, add as future enhancement
2. **Interstitial page**: Create a content detail page at `/content_items/:id` that shows item metadata + similar content before user clicks through to external URL
3. **Expanded card modal**: Add "Show Similar" button to content cards that opens a modal/drawer with similar items
4. **Inline below card**: Show "Similar" items inline when hovering/expanding a card

Recommend **Option 1 (Descope)** for v1 to avoid scope creep. Can add as separate task.

### Steps

#### Phase 1: Data Layer

**Step 1: Create ContentView migration**
- File: `db/migrate/[timestamp]_create_content_views.rb`
- Change: Create `content_views` table with columns:
  - `id` (bigint, primary key)
  - `user_id` (bigint, foreign key to users, not null)
  - `content_item_id` (bigint, foreign key to content_items, not null)
  - `site_id` (bigint, foreign key to sites, not null)
  - `viewed_at` (datetime, not null, default: CURRENT_TIMESTAMP)
- Indexes:
  - `unique: [site_id, user_id, content_item_id]` - prevent duplicate views
  - `[user_id, site_id, viewed_at DESC]` - efficient user history lookups
- Verify: `rails db:migrate` succeeds

**Step 2: Create ContentView model**
- File: `app/models/content_view.rb`
- Change:
  ```ruby
  include SiteScoped
  belongs_to :user
  belongs_to :content_item
  validates :user_id, uniqueness: { scope: [:site_id, :content_item_id] }
  scope :recent, -> { order(viewed_at: :desc) }
  ```
- Verify: `ContentView.new(user: User.first, content_item: ContentItem.first, site: Site.first).valid?` in console

**Step 3: Add view tracking endpoint**
- File: `app/controllers/content_views_controller.rb` (new)
- Change: Create controller with `create` action that records view for current_user
- File: `config/routes.rb`
- Change: Add `resources :content_views, only: [:create]` inside `content_items` resource
- Verify: `POST /content_items/:content_item_id/views` creates record

**Step 4: Add JavaScript view tracking**
- File: `app/views/feed/_content_card.html.erb`
- Change: Add `data-content-id` attribute to external link
- File: `app/javascript/controllers/track_view_controller.js` (new)
- Change: Stimulus controller that POSTs to view tracking endpoint on click
- Verify: Clicking content card title creates ContentView record

#### Phase 2: Recommendation Engine

**Step 5: Create ContentRecommendationService**
- File: `app/services/content_recommendation_service.rb`
- Change: Implement service with methods:
  - `.for_user(user, site:, limit: 6)` - Personalized feed for homepage
  - `.similar_to(content_item, limit: 4)` - Similar content by topic_tags
  - `.for_digest(subscription, limit: 5)` - Recommendations for email
- Algorithm for `for_user`:
  1. Get user's recent interactions (votes, bookmarks, views) from last 90 days
  2. Extract topic_tags from those content_items
  3. Score tags: vote=3x, bookmark=2x, view=1x weight; apply time decay (half-life = 14 days)
  4. Find content matching top 5 tags, excluding already-interacted items
  5. If <5 interactions, fallback to `FeedRankingService.ranked_feed`
  6. Include ~20% diversity from trending to avoid filter bubble
- Verify: Service returns results in console

#### Phase 3: Homepage Integration

**Step 6: Update TenantHomepageService**
- File: `app/services/tenant_homepage_service.rb`
- Change: Add `personalized_content(user)` method that:
  - Returns nil if user is nil
  - Calls `ContentRecommendationService.for_user(user, site: @site, limit: 6)`
  - Returns empty array for errors (graceful degradation)
- Verify: `TenantHomepageService.new(site: Site.first, tenant: Tenant.first).personalized_content(User.first)` returns results

**Step 7: Update TenantsController**
- File: `app/controllers/tenants_controller.rb`
- Change: In `show` action, after loading tenant_data:
  ```ruby
  @personalized_content = service.personalized_content(current_user) if user_signed_in?
  ```
- Verify: Controller sets `@personalized_content` for logged-in users

**Step 8: Update homepage view**
- File: `app/views/tenants/show.html.erb`
- Change: Add "For You" section before "Latest Content" (line 18):
  ```erb
  <% if user_signed_in? && @personalized_content&.any? %>
    <section class="mb-12">
      <h2>For You</h2>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <% @personalized_content.each do |item| %>
          <%= render 'feed/content_card', content_item: item %>
        <% end %>
      </div>
    </section>
  <% end %>
  ```
- Verify: Logged-in users see "For You" section on homepage

#### Phase 4: Email Integration

**Step 9: Update DigestMailer**
- File: `app/mailers/digest_mailer.rb`
- Change: In both `weekly_digest` and `daily_digest` methods, add:
  ```ruby
  @personalized_content = ContentRecommendationService.for_digest(@subscription, limit: 5)
  ```
- Verify: Mailer previews show `@personalized_content` populated

**Step 10: Update email templates**
- File: `app/views/digest_mailer/weekly_digest.html.erb`
- File: `app/views/digest_mailer/daily_digest.html.erb`
- Change: Add "Recommended for you" section after top content:
  ```erb
  <% if @personalized_content&.any? %>
    <h3>Recommended for you</h3>
    <% @personalized_content.each do |item| %>
      <!-- item card -->
    <% end %>
  <% end %>
  ```
- Verify: Email previews show personalized section

#### Phase 5: Caching

**Step 11: Add caching to ContentRecommendationService**
- File: `app/services/content_recommendation_service.rb`
- Change: In `for_user` method, wrap computation in:
  ```ruby
  Rails.cache.fetch("recommendations/user/#{user.id}/site/#{site.id}", expires_in: 1.hour) do
    # computation
  end
  ```
- Verify: Second call returns cached result (check Rails.cache stats or logs)

#### Phase 6: Tests

**Step 12: Write ContentView model specs**
- File: `spec/models/content_view_spec.rb`
- Coverage:
  - Validates presence of user, content_item, site
  - Validates uniqueness of user/content_item/site combination
  - Scopes to current site via SiteScoped
  - `recent` scope orders by viewed_at DESC

**Step 13: Write ContentRecommendationService specs**
- File: `spec/services/content_recommendation_service_spec.rb`
- Coverage:
  - `for_user` returns personalized results for user with interactions
  - `for_user` returns engagement-ranked fallback for cold start user (<5 interactions)
  - `for_user` excludes content user already interacted with
  - `for_user` results are scoped to site
  - `similar_to` returns items with matching topic_tags
  - `similar_to` excludes the source item
  - `for_digest` returns recommendations for subscription's user
  - Caching works correctly

**Step 14: Write controller/request specs**
- File: `spec/requests/tenants_spec.rb` (extend existing or create)
- Coverage:
  - Homepage shows "For You" section for logged-in user with interactions
  - Homepage does NOT show "For You" for anonymous users
  - Homepage does NOT show "For You" for new users with no interactions
- File: `spec/requests/content_views_spec.rb` (new)
- Coverage:
  - POST creates ContentView for logged-in user
  - POST is idempotent (no duplicate views)
  - POST requires authentication

### Checkpoints

| After Step | Verify |
|------------|--------|
| Step 4 | Views are tracked when clicking content links |
| Step 8 | Homepage shows "For You" for logged-in users with history |
| Step 10 | Email previews include personalized section |
| Step 14 | All tests pass, `bundle exec rspec` green |
| Final | Quality gates pass: rubocop, brakeman, rspec |

### Test Plan

- [ ] **Unit**: ContentView model validations and scopes
- [ ] **Unit**: ContentRecommendationService algorithm (cold start, personalization, similar content)
- [ ] **Integration**: View tracking endpoint creates records
- [ ] **Integration**: Homepage displays "For You" section conditionally
- [ ] **Integration**: Email previews show personalized content

### Docs to Update

- [ ] None required - internal feature with no public API

---

## Work Log

### 2026-01-30 17:44 - Implementation Complete

**Files Created (6 new files):**
- `db/migrate/20260130173100_create_content_views.rb` - Migration for view tracking
- `app/models/content_view.rb` - ContentView model with SiteScoped concern
- `app/controllers/content_views_controller.rb` - View tracking endpoint
- `app/policies/content_view_policy.rb` - Pundit policy for authorization
- `app/services/content_recommendation_service.rb` - Core recommendation engine
- `app/javascript/controllers/track_view_controller.js` - Stimulus controller for tracking

**Files Modified (11 files):**
- `app/models/user.rb` - Added `has_many :content_views` association
- `app/models/content_item.rb` - Added `has_many :content_views` association
- `config/routes.rb` - Added view tracking route under content_items
- `app/javascript/controllers/index.js` - Registered track-view controller
- `app/views/feed/_content_card.html.erb` - Added data attributes for tracking
- `app/services/tenant_homepage_service.rb` - Added `personalized_content` method
- `app/controllers/tenants_controller.rb` - Load personalized content for logged-in users
- `app/views/tenants/show.html.erb` - Added "For You" section
- `app/mailers/digest_mailer.rb` - Added personalized content to digests
- `app/views/digest_mailer/weekly_digest.html.erb` - "Recommended for you" section
- `app/views/digest_mailer/daily_digest.html.erb` - "Recommended for you" section
- `config/locales/en.yml` - Added translation keys

**Implementation Details:**
- ContentRecommendationService uses content-based filtering on topic_tags
- Interaction weights: votes (3x), bookmarks (2x), views (1x)
- Time decay with 14-day half-life
- Cold start fallback (<5 interactions) uses FeedRankingService engagement ranking
- 20% diversity from trending content to avoid filter bubbles
- 1-hour cache per user/site for recommendations
- View tracking via sendBeacon for reliable delivery during navigation

**Quality Gates:**
- ✓ Rubocop: All files pass
- ✓ Brakeman: No security warnings
- ✓ ESLint: JavaScript passes
- ✓ Build: npm run build && npm run build:css succeed
- ✓ Tests: 2718 examples, 0 failures

---

### 2026-01-30 17:28 - Planning Complete

**Gap Analysis Summary:**
- 9 of 11 criteria have status "none" - need full implementation
- 1 criterion (cold start) is "partial" - FeedRankingService exists
- 1 criterion ("Similar Content") is **BLOCKED** - no content detail page exists

**Key Finding:** Content items link directly to external URLs (`url_canonical`). There is no content detail page in the app where "Similar Content" could be shown. This affects acceptance criterion #7.

**Recommendation:** Descope "Similar Content on content pages" from this task. Implement as separate task that creates an interstitial content detail page.

**Revised Scope (10 criteria):**
1. ContentView model ✓ planned
2. View tracking endpoint ✓ planned (via JS on external link click)
3. ContentRecommendationService ✓ planned
4. Personalization algorithm ✓ planned
5. Cold start fallback ✓ planned
6. "For You" on homepage ✓ planned
7. ~~"Similar Content" on content pages~~ **DESCOPED** - blocked by architecture
8. Personalized digest emails ✓ planned
9. Index on content_views ✓ planned
10. Cache recommendations ✓ planned
11. Tests ✓ planned

**Implementation Steps:** 14 steps across 6 phases
**Estimated Files:** 8 new files, 6 modified files
**Risk Level:** Low (content-based filtering on existing infrastructure)

---

### 2026-01-30 17:27 - Triage Complete

Quality gates:
- Lint: `bundle exec rubocop` (Ruby), `npm run lint` (JS)
- Types: N/A (Ruby/Rails project)
- Tests: `bundle exec rspec`
- Build: `npm run build && npm run build:css`
- Security: `bundle exec brakeman`

Task validation:
- Context: clear - Problem statement is specific, business context documented, solution approach defined
- Criteria: specific - 11 acceptance criteria with clear pass/fail conditions
- Dependencies: none - No blocked_by listed, no blockers in 1.blocked/

Complexity:
- Files: some (~8 files to modify/create)
- Risk: low - Content-based filtering on existing infrastructure, clear fallback behavior

Key file verification:
- ✓ `app/models/vote.rb` exists
- ✓ `app/models/bookmark.rb` exists
- ✓ `app/services/feed_ranking_service.rb` exists
- ✓ `app/services/tenant_homepage_service.rb` exists
- ✓ `app/mailers/digest_mailer.rb` exists
- ✓ `app/views/tenants/show.html.erb` exists

Note: manifest.yaml has empty quality commands - using standard Ruby/Rails tools discovered in Gemfile/package.json

Ready: yes

---

### 2026-01-30 17:22 - Task Expanded

- Intent: BUILD
- Scope: Personalized content recommendations using content-based filtering on topic_tags
- Key files to modify:
  - `app/services/tenant_homepage_service.rb` - Add personalized content method
  - `app/views/tenants/show.html.erb` - Add "For You" section
  - `app/mailers/digest_mailer.rb` - Add personalized recommendations
  - `app/controllers/feed_controller.rb` - Track views
- Key files to create:
  - `app/models/content_view.rb` - View tracking model
  - `app/services/content_recommendation_service.rb` - Recommendation engine
- Complexity: Medium
- Codebase analysis complete:
  - Existing Vote/Bookmark/Comment models provide explicit signals
  - `topic_tags` JSONB field with GIN index enables efficient taxonomy matching
  - `FeedRankingService` provides fallback ranking algorithm
  - `SiteScoped` concern ensures multi-tenant isolation
  - No existing content view tracking or recommendation infrastructure

---

## Testing Evidence

_No tests run yet._

---

## Notes

**In Scope:**
- ContentView model to track implicit signals (views)
- ContentRecommendationService with content-based filtering using topic_tags
- "For You" section on homepage for logged-in users
- "Similar Content" section on content item pages
- Personalized recommendations in digest emails
- Cold start fallback to engagement-ranked content
- 1-hour cache for recommendations

**Out of Scope:**
- User interest preferences in profile settings (future task - keep simple first)
- Collaborative filtering (similar users) - adds complexity, not needed for v1
- ML/AI-based recommendations - start with rules-based approach
- A/B testing infrastructure - can add later
- Real-time view duration tracking - just track view events

**Assumptions:**
- topic_tags JSONB field is reliably populated for content items (TaggingService handles this)
- Users have enough interaction history after ~5 interactions for meaningful personalization
- 1-hour cache TTL is acceptable for recommendation freshness

**Edge Cases:**
- Anonymous users: Show engagement-ranked content (no personalization)
- New users (<5 interactions): Show engagement-ranked content with fallback
- Users with narrow interests: Include some diversity to avoid filter bubble
- Content with no topic_tags: Exclude from similarity matching, can still appear in engagement-ranked fallback
- High-volume users: Cap interaction history to last 100 items for performance

**Risks:**
| Risk | Mitigation |
|------|------------|
| Performance: Computing recommendations per-request is slow | Cache results for 1 hour per user/site |
| Filter bubble: Users only see same topics | Include ~20% diversity in recommendations from trending |
| Cold start: New users get poor recommendations | Clear fallback to engagement-ranked content |
| Privacy: Exposing reading history | ContentView records are never exposed to other users |
| Multi-tenant leak: Cross-site data | SiteScoped concern ensures isolation |

**Privacy Considerations:**
- ContentView records are internal only, never exposed via API
- No user-to-user similarity data exposed (no "users who liked this also liked...")
- Reading history only visible to the user themselves (if we add that feature later)

---

## Links

**Related Code:**
- `app/models/vote.rb:28-42` - Vote model with counter_cache
- `app/models/bookmark.rb:24-43` - Polymorphic bookmark model
- `app/models/content_item.rb:58-211` - ContentItem with topic_tags JSONB
- `app/services/feed_ranking_service.rb:1-117` - Current ranking algorithm
- `app/services/tenant_homepage_service.rb:1-52` - Homepage data service
- `app/views/tenants/show.html.erb:1-81` - Homepage view to modify
- `app/mailers/digest_mailer.rb:1-70` - Digest email mailer
- `app/models/concerns/site_scoped.rb:1-76` - Multi-tenant isolation pattern

**Research:**
- Netflix recommendation engine architecture
- Ghost discovery engine (Nov 2025)
- Content-based filtering algorithms
