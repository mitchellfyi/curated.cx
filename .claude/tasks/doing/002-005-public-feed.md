# Task: Implement Public Feed for Sites

## Metadata

| Field | Value |
|-------|-------|
| ID | `002-005-public-feed` |
| Status | `doing` |
| Priority | `002` High |
| Created | `2025-01-23 00:05` |
| Started | `2026-01-23 08:52` |
| Completed | |
| Blocked By | `002-004-ai-editorialisation` |
| Blocks | `002-006-community-primitives` |
| Assigned To | `worker-1` |
| Assigned At | `2026-01-23 08:52` |

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

### Implementation Plan (Generated 2026-01-23 08:55)

#### Gap Analysis

| Criterion | Status | Gap |
|-----------|--------|-----|
| Site homepage shows ranked content feed | partial | Homepage exists (`app/views/tenants/show.html.erb`) but uses Listing model, not ContentItem; no ranking |
| Pagination working | no | No pagination gem installed; need to add pagy or manual cursor pagination |
| Filter by tag (from taxonomy) | partial | `tagged_with` scope exists on ContentItem; no UI; Taxonomy model exists |
| Filter by content type | partial | `by_content_type` scope exists on ContentItem; `content_type` field exists; no UI |
| "Top this week" view available | no | No time-range filtering logic; needs time scope + engagement-based sort |
| "Latest" view available | partial | `.recent` scope exists; just needs UI toggle |
| Ranking: Freshness decay | no | No ranking calculation; `published_at` exists for calculation |
| Ranking: Source quality weight | no | Need `quality_weight` field on Source model |
| Ranking: Engagement signals | no | Need migration for `upvotes_count`, `comments_count`; placeholder until community features |
| Feed performance optimized | partial | Basic indexes exist; need composite indexes for ranking queries + caching |
| SEO meta tags on feed pages | partial | `meta-tags` gem installed; need to call `set_page_meta_tags` with feed-specific content |
| Mobile responsive design | partial | Tailwind in use; existing card designs are responsive; need to verify new components |
| RSS feed endpoint | no | No RSS implementation exists |
| Tests cover ranking order | no | Need new spec file with ranking fixtures |
| `docs/ranking.md` | no | Need to create documentation |
| Quality gates pass | tbd | Must verify at end |
| Changes committed | tbd | Must do at end |

#### Files to Create

1. **`app/services/feed_ranking_service.rb`** - Core ranking logic
   - `ranked_feed(site:, filters:, limit:, offset:)` - Main entry point
   - `calculate_score(content_item)` - Ranking algorithm
   - Constants for decay rate, weight factors
   - Caching support for computed scores

2. **`app/controllers/feed_controller.rb`** - Feed endpoints
   - `index` action - Main ranked feed with filters
   - `rss` action - RSS 2.0 feed
   - Strong params for filters: `tag`, `content_type`, `sort`, `page`
   - Pundit authorization using ContentItem policy

3. **`app/views/feed/index.html.erb`** - Feed page with filters
   - Filter bar (tags, content types, sort options)
   - Content cards grid
   - Pagination controls
   - Empty state

4. **`app/views/feed/_content_card.html.erb`** - Reusable content card partial
   - Title with link
   - AI summary or description fallback
   - Source name + published time
   - Topic tags as pills
   - Responsive layout matching existing patterns

5. **`app/views/feed/index.rss.builder`** - RSS feed template
   - RSS 2.0 format
   - Channel metadata (title, description, link)
   - Items with title, link, description, pubDate, guid

6. **`app/policies/content_item_policy.rb`** - Authorization (if not exists)
   - `index?` - Allow for all
   - `show?` - Allow for published items
   - Policy scope filters to site's published items

7. **`db/migrate/YYYYMMDDHHMMSS_add_feed_ranking_fields.rb`** - Schema additions
   - `sources.quality_weight` - decimal, default 1.0
   - `content_items.upvotes_count` - integer, default 0
   - `content_items.comments_count` - integer, default 0
   - `content_items.engagement_score` - decimal (cached ranking, optional)
   - Indexes: `(site_id, published_at DESC)`, GIN on `topic_tags`

8. **`spec/services/feed_ranking_service_spec.rb`** - Ranking tests
   - Score calculation for freshness decay
   - Source quality weight impact
   - Engagement score calculation
   - Sort order verification with fixtures
   - Filter combinations

9. **`spec/controllers/feed_controller_spec.rb`** - Controller tests
   - Index action returns ContentItems
   - Filter by tag works
   - Filter by content_type works
   - Sort options (latest, top_week, ranked)
   - RSS feed renders correctly
   - Pagination works

10. **`docs/ranking.md`** - Algorithm documentation
    - Formula explanation
    - Weight tuning guidance
    - Future improvements (personalization, ML)

#### Files to Modify

1. **`app/models/content_item.rb`** - Add ranking-related methods
   - Add scopes: `for_feed`, `top_this_week`, `by_engagement`
   - Add methods for cached engagement score
   - Ensure topic_tags accessor works

2. **`app/models/source.rb`** - Add quality weight
   - Add accessor for `quality_weight` with default 1.0
   - Add validation for quality_weight range (0.0 - 2.0)

3. **`config/routes.rb`** - Add feed routes
   - `resources :feed, only: [:index]`
   - `get 'feed/rss', to: 'feed#rss', as: :feed_rss, defaults: { format: :rss }`

4. **`app/views/tenants/show.html.erb`** - Transition to ContentItem feed
   - Replace Listing-based feed with FeedRankingService
   - Add link to full feed page
   - Keep responsive grid layout

5. **`app/controllers/tenants_controller.rb`** - Use new service
   - Replace `Listing.recent_published_for_tenant` with `FeedRankingService.ranked_feed`

6. **`config/locales/en.yml`** - Add i18n keys
   - `feed.index.title`, `feed.filters.*`, `feed.rss.*`
   - `feed.sort.latest`, `feed.sort.top_week`, `feed.sort.ranked`

7. **`spec/factories/content_items.rb`** - Enhance factory
   - Add traits: `:with_engagement`, `:recent`, `:old`, `:high_quality_source`
   - Add sequence for varied published_at times

#### Test Plan

- [ ] Unit: FeedRankingService calculates correct scores
- [ ] Unit: Freshness decay works (newer items score higher)
- [ ] Unit: Source quality weight multiplies correctly
- [ ] Unit: Engagement score calculation (upvotes + comments * 0.5)
- [ ] Unit: Filters by tag reduce results correctly
- [ ] Unit: Filters by content_type work
- [ ] Unit: Time range filter (top_this_week) works
- [ ] Controller: Index action returns 200 with feed
- [ ] Controller: RSS action returns valid RSS XML
- [ ] Controller: Pagination params work
- [ ] Controller: Filter params applied correctly
- [ ] Integration: Feed page renders without errors
- [ ] Integration: Mobile view is responsive

#### Docs to Update

- [ ] Create `docs/ranking.md` with:
  - Formula: `score = freshness * 0.4 + source_quality * 0.3 + engagement * 0.3`
  - Freshness decay: `freshness = 1 / (1 + hours_ago / 24)`
  - Engagement: `engagement = (upvotes + comments * 0.5) / max_engagement`
  - Tuning guidance for weights
  - Future roadmap (personalization, A/B testing)

#### Implementation Order

1. **Migration first** - Add database fields
2. **Model changes** - Add scopes and validations to ContentItem, Source
3. **FeedRankingService** - Core ranking logic with tests
4. **Routes + Controller** - Wire up endpoints
5. **Views** - Feed page, cards, RSS template
6. **i18n** - Add translation keys
7. **Update homepage** - Transition tenants#show to use new service
8. **Documentation** - Write docs/ranking.md
9. **Quality gates** - Run ./bin/quality, fix any issues
10. **Commit** - With task reference

---

## Work Log

### 2026-01-23 09:10 - Testing Phase Complete

Tests written:
- `spec/services/feed_ranking_service_spec.rb` - 21 examples
- `spec/requests/feed_spec.rb` - 26 examples
- `spec/policies/content_item_policy_spec.rb` - 24 examples

Factory enhancements:
- `spec/factories/content_items.rb` - 9 new traits
- `spec/factories/sources.rb` - 3 new traits

Test results:
- Cannot run (PostgreSQL not available)
- Syntactically valid (passes Ruby parse)
- Follows codebase test patterns

Quality gates:
- RuboCop: ✅ pass
- Brakeman: ⚠️ 2 false positive SQL injection warnings (documented)

Commit: `0136d3d` - test: Add specs for feed feature [002-005-public-feed]

### 2026-01-23 09:06 - Implementation Phase Complete

**Commits Made (12 total):**
1. `bd111b7` - Migration for feed ranking fields
2. `1533fe3` - Feed scopes on ContentItem model
3. `f2e653d` - quality_weight validation on Source model
4. `cf67424` - FeedRankingService (core ranking logic)
5. `9d0b7f0` - Feed routes (index, rss)
6. `736fdd9` - ContentItemPolicy + FeedController
7. `9f60f21` - Feed views (index, content_card partial)
8. `a3f1f3c` - RSS 2.0 template
9. `fdb8879` - i18n translation keys
10. `f23d25d` - Updated homepage to use feed
11. `5a08dd3` - Safety comments on Arel.sql calls

**Files Created:**
- `db/migrate/20260123085712_add_feed_ranking_fields.rb`
- `app/services/feed_ranking_service.rb`
- `app/controllers/feed_controller.rb`
- `app/policies/content_item_policy.rb`
- `app/views/feed/index.html.erb`
- `app/views/feed/_content_card.html.erb`
- `app/views/feed/rss.rss.builder`

**Files Modified:**
- `app/models/content_item.rb` - Added feed scopes
- `app/models/source.rb` - Added quality_weight validation
- `config/routes.rb` - Added feed routes
- `config/locales/en.yml` - Added feed translation keys
- `app/controllers/tenants_controller.rb` - Uses FeedRankingService
- `app/views/tenants/show.html.erb` - Renders ContentItems

**Quality Checks:**
- RuboCop: All files pass
- ERB Lint: All templates pass
- Brakeman: 2 SQL injection warnings (false positives - SQL built from constants only)

**Notes:**
- Database migration not run (PostgreSQL not available in this session)
- Tests deferred to TEST phase
- Documentation deferred to DOCS phase

### 2026-01-23 08:55 - Planning Complete

Comprehensive codebase analysis completed. Key findings:

**Existing Infrastructure:**
- ContentItem model exists with `published_at`, `topic_tags`, `content_type`, `ai_summary`, `why_it_matters`
- Scopes exist: `.recent`, `.published`, `.by_content_type`, `.tagged_with(taxonomy_slug)`
- Taxonomy model exists for hierarchical tags with slugs
- TaggingService applies rules and assigns `topic_tags` on content creation
- Homepage (`tenants#show`) uses Listing model - needs transition to ContentItem
- Tailwind + Hotwire frontend; responsive patterns established
- Pundit for authorization; meta-tags gem for SEO
- No pagination gem installed; no RSS implementation

**Key Gaps Identified:**
- No ranking algorithm or FeedRankingService
- No quality_weight on Source model
- No engagement fields (upvotes_count, comments_count) on ContentItem
- No feed-specific routes, controller, or views
- No RSS endpoint
- No docs/ranking.md

**Plan Created:**
- 10 files to create (service, controller, views, policy, migration, specs, docs)
- 7 files to modify (models, routes, locales, factories)
- 13 test cases planned
- Clear implementation order defined

Ready for implementation phase.

### 2026-01-23 08:52 - Triage Complete

- Dependencies: ✅ `002-004-ai-editorialisation` is completed (done: 2026-01-23 08:48)
- Task clarity: Clear - well-defined acceptance criteria with specific features
- Ready to proceed: Yes
- Notes:
  - Task has 17 acceptance criteria covering feed display, filtering, ranking, performance, RSS, and documentation
  - Plan is well-structured with 9 implementation steps
  - ContentItem model should already exist from prior tasks (002-002 ingest pipeline)
  - Will need to verify existing models and add ranking-related fields/methods

---

## Testing Evidence

### 2026-01-23 09:10 - Testing Phase Complete

**Spec Files Created:**
- `spec/services/feed_ranking_service_spec.rb` - 21 examples
  - Score calculation for freshness decay (newer items rank higher)
  - Source quality weight impact (high quality sources rank higher)
  - Engagement signals (upvotes + comments boost rank)
  - Filtering by tag, content_type, combined filters
  - Sort modes: latest, top_week, ranked
  - Limit and offset pagination

- `spec/requests/feed_spec.rb` - 26 examples
  - Index action returns ContentItems with proper assignments
  - RSS action returns valid RSS 2.0 XML
  - Filter params (tag, content_type) applied correctly
  - Sort params (latest, top_week, ranked) work
  - Pagination (20 per page, page param)
  - Private tenant requires authentication
  - Meta tags and RSS alternate link present
  - Site isolation (only shows current site's content)

- `spec/policies/content_item_policy_spec.rb` - 24 examples
  - index? allows public access unless tenant requires login
  - show? requires item to be published
  - create?/update?/destroy? require editor/admin/owner roles
  - Scope filters by current site

**Factory Enhancements:**
- `spec/factories/content_items.rb`:
  - `:published`, `:unpublished` traits (existed)
  - `:recent`, `:old` traits (new)
  - `:with_engagement`, `:high_engagement`, `:low_engagement` (new)
  - `:with_ai_content`, `:article`, `:video`, `:tagged_tech` (new)

- `spec/factories/sources.rb`:
  - `:high_quality`, `:low_quality` traits (new)
  - `:with_editorialisation` trait (new)

**Quality Gate Results:**
- RuboCop: ✅ All spec files pass (0 offenses)
- Brakeman: ⚠️ 2 SQL injection warnings (false positives - SQL from constants only)

**Commit:**
- `0136d3d` - test: Add specs for feed feature [002-005-public-feed]

**Notes:**
- PostgreSQL not running in this session, so specs cannot be executed
- Specs are syntactically correct and follow codebase patterns
- Tests will be verified when database is available

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
