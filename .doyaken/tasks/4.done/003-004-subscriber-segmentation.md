# Task: Subscriber Segmentation & Dynamic Content

## Metadata

| Field       | Value                                                  |
| ----------- | ------------------------------------------------------ |
| ID          | `003-004-subscriber-segmentation`                      |
| Status      | `done`                                                 |
| Priority    | `003` Medium                                           |
| Created     | `2026-01-30 15:30`                                     |
| Started     | `2026-01-30 23:27`                                     |
| Completed   | `2026-01-31 00:15`                                     |
| Blocked By  |                                                        |
| Blocks      |                                                        |
| Assigned To |  |
| Assigned At |  |

---

## Context

**Intent**: BUILD

**Problem**: Publishers cannot segment their subscriber list or send targeted content to specific groups. All subscribers receive identical digest emails regardless of their interests, engagement level, or subscription history.

**Solution**: Implement a rule-based subscriber segmentation system that allows publishers to:
1. Define segments using JSONB rule criteria (engagement, recency, referral status, tags)
2. Manually tag subscribers for custom segments
3. Auto-segment subscribers based on behavioral rules
4. Target digest sends to specific segments

**Why This Matters**:
- **Competitive Parity**: beehiiv and Kit offer segmentation; this is table stakes
- **Industry Trend**: Hyper-personalization at scale (40% growth expected in 2026)
- **User Value**: Publishers can send relevant content to engaged subscribers, reducing unsubscribes
- **RICE Score**: 96 (Reach: 800, Impact: 1.5, Confidence: 80%, Effort: 1 person-week)

**Existing Infrastructure**:
- `DigestSubscription` model with `last_sent_at`, `created_at`, `preferences` (JSONB), `active` status
- `Vote`, `Bookmark`, `ContentView` models track user engagement (linked via `user_id`)
- `Referral` model tracks subscriber referrals (`confirmed_referrals_count` method exists)
- `TaggingRule` model provides a pattern for rule-based evaluation (can follow similar design)
- `SiteScoped` and `TenantScoped` concerns for multi-tenant isolation
- `SendDigestEmailsJob` already filters by frequency; needs segment filtering
- No email open/click tracking currently exists (out of scope for this task)

---

## Acceptance Criteria

All must be checked before moving to done:

### Models & Database
- [x] `SubscriberSegment` model exists with: `name`, `site_id`, `tenant_id`, `rules` (JSONB), `system_segment` (boolean), `enabled` (boolean)
- [x] `SubscriberTag` model exists with: `name`, `slug`, `site_id`, `tenant_id`
- [x] `SubscriberTagging` join model exists linking `DigestSubscription` to `SubscriberTag`
- [x] Migrations run cleanly with appropriate indexes

### Segmentation Rules
- [x] Rules can filter by: `subscription_age` (days since signup), `engagement_level` (based on votes/bookmarks/views), `referral_count` (number of confirmed referrals), `tags` (has specific tags), `frequency` (weekly/daily), `active` (true/false)
- [x] System segments auto-created on site creation: "All Subscribers", "Active (30 days)", "New (7 days)", "Power Users (3+ referrals)"
- [x] `SegmentationService.subscribers_for(segment)` returns matching `DigestSubscription` records

### Manual Tagging
- [x] Admin can create/edit/delete tags via `Admin::SubscriberTagsController`
- [x] Admin can assign/remove tags from individual subscribers
- [x] Tags usable as segment rule criteria

### Digest Integration
- [x] `SendDigestEmailsJob` accepts optional `segment_id` parameter
- [x] When segment specified, only matching subscribers receive digest
- [x] Segment filtering works with existing frequency filtering

### Admin UI
- [x] Admin can view all segments with subscriber counts
- [x] Admin can create/edit/delete custom segments (not system segments)
- [x] Admin can preview segment rules (show matching count before save)

### Tests
- [x] Model specs for `SubscriberSegment`, `SubscriberTag`, `SubscriberTagging`
- [x] Service spec for `SegmentationService` covering all rule types
- [x] Request specs for admin segment/tag controllers
- [x] Job spec for segment-filtered digest sending
- [x] All tests passing

### Quality
- [x] Quality gates pass (`bin/rubocop`, `bin/brakeman`, tests)
- [x] Changes committed with task reference [003-004-subscriber-segmentation]

---

## Plan

### Gap Analysis

| Criterion | Status | Gap |
|-----------|--------|-----|
| SubscriberSegment model | None | Build from scratch - new model, migration |
| SubscriberTag model | None | Build from scratch - new model, migration |
| SubscriberTagging join | None | Build from scratch - new join model, migration |
| Rule evaluation service | None | Build SegmentationService (follow TaggingRule pattern) |
| subscription_age filter | None | Build SQL query using `created_at` |
| engagement_level filter | None | Build SQL with subquery joining Vote/Bookmark/ContentView |
| referral_count filter | None | Build SQL with subquery joining Referral |
| tags filter | None | Build SQL with JOIN on subscriber_taggings |
| frequency filter | Full | DigestSubscription already has `frequency` enum |
| active filter | Full | DigestSubscription already has `active` boolean |
| System segments on site creation | None | Add callback to Site model |
| Admin tags CRUD | None | Build controller + views (follow TaggingRulesController pattern) |
| Admin segments CRUD | None | Build controller + views (follow TaggingRulesController pattern) |
| Tag assignment UI | None | Build inline assignment on subscriber/segment views |
| SendDigestEmailsJob segment param | Partial | Job exists, add optional segment_id param |
| Model specs | None | Write specs for 3 new models |
| Service spec | None | Write spec for SegmentationService |
| Request specs | None | Write specs for 2 admin controllers |
| Job spec | Partial | Existing job spec, add segment filtering tests |

### Risks

- [ ] **Performance on large lists**: Evaluating rules for 10k+ subscribers
  - Mitigation: Use efficient SQL queries with proper indexes; avoid Ruby iteration; benchmark during implementation
- [ ] **Engagement join complexity**: Bookmark model lacks `site_id` (polymorphic through bookmarkable)
  - Mitigation: Join through ContentItem to get site_id, or use user_id only for bookmarks
- [ ] **Stale system segments**: If system segment definitions change, existing segments won't auto-update
  - Mitigation: Document this; system segments are non-editable but rules are fixed at creation
- [ ] **Empty segment edge case**: Sending to 0 subscribers
  - Mitigation: Log warning in job; acceptable behavior (job runs, sends nothing)

### Steps

#### Phase 1: Database & Models (Steps 1-4)

**Step 1: Create SubscriberTag model and migration**
- File: `db/migrate/TIMESTAMP_create_subscriber_tags.rb`
  - `name` (string, not null)
  - `slug` (string, not null)
  - `site_id` (bigint, FK, not null)
  - `tenant_id` (bigint, FK, not null)
  - Index: `(site_id, slug)` unique
  - Index: `(tenant_id)`
- File: `app/models/subscriber_tag.rb`
  - Include: `SiteScoped` (auto-includes TenantScoped via set_tenant_from_site)
  - Validations: name presence, slug presence + format + uniqueness per site
  - Callback: `before_validation :generate_slug, on: :create`
  - Association: `has_many :subscriber_taggings, dependent: :destroy`
- Verify: `bin/rails db:migrate` runs; `SubscriberTag.new(name: "Test", site: site).valid?` returns true

**Step 2: Create SubscriberTagging join model**
- File: `db/migrate/TIMESTAMP_create_subscriber_taggings.rb`
  - `digest_subscription_id` (bigint, FK, not null)
  - `subscriber_tag_id` (bigint, FK, not null)
  - Index: `(digest_subscription_id, subscriber_tag_id)` unique
  - Index: `(subscriber_tag_id)`
- File: `app/models/subscriber_tagging.rb`
  - `belongs_to :digest_subscription`
  - `belongs_to :subscriber_tag`
  - Validations: uniqueness of pair
- Verify: Can create tagging; duplicate rejected

**Step 3: Create SubscriberSegment model**
- File: `db/migrate/TIMESTAMP_create_subscriber_segments.rb`
  - `name` (string, not null)
  - `description` (text)
  - `rules` (jsonb, default: {}, not null)
  - `system_segment` (boolean, default: false, not null)
  - `enabled` (boolean, default: true, not null)
  - `site_id` (bigint, FK, not null)
  - `tenant_id` (bigint, FK, not null)
  - Index: `(site_id, enabled)`
  - Index: `(site_id, system_segment)`
  - Index: `(tenant_id)`
- File: `app/models/subscriber_segment.rb`
  - Include: `SiteScoped`
  - Validations: name presence
  - Scopes: `enabled`, `system`, `custom` (non-system)
  - Method: `rules` returns `super || {}`
  - Method: `editable?` returns `!system_segment?`
- Verify: `bin/rails db:migrate` runs; JSONB rules set/read works

**Step 4: Update DigestSubscription associations**
- File: `app/models/digest_subscription.rb`
  - Add: `has_many :subscriber_taggings, dependent: :destroy`
  - Add: `has_many :subscriber_tags, through: :subscriber_taggings`
- Verify: `subscription.subscriber_tags` returns empty relation; can assign tags

#### Phase 2: Segmentation Service (Steps 5-6)

**Step 5: Create SegmentationService**
- File: `app/services/segmentation_service.rb`
- Public API: `SegmentationService.subscribers_for(segment)` → ActiveRecord::Relation of DigestSubscription
- Rules format (JSONB):
  ```json
  {
    "subscription_age": { "min_days": 7, "max_days": null },
    "engagement_level": { "min_actions": 5, "within_days": 30 },
    "referral_count": { "min": 3 },
    "tags": { "any": ["vip", "beta"], "all": [] },
    "frequency": "weekly",
    "active": true
  }
  ```
- Private methods (each returns scope):
  - `apply_subscription_age_rule(scope, rule)` - Filter by `created_at`
  - `apply_engagement_rule(scope, rule)` - Subquery: COUNT votes + bookmarks + content_views WHERE user_id matches AND created_at within window
  - `apply_referral_count_rule(scope, rule)` - Subquery: COUNT referrals WHERE referrer_subscription_id AND status IN (confirmed, rewarded)
  - `apply_tags_rule(scope, rule)` - JOIN subscriber_taggings WHERE tag slugs match (ANY/ALL logic)
  - `apply_frequency_rule(scope, rule)` - WHERE frequency = value
  - `apply_active_rule(scope, rule)` - WHERE active = value
- Empty rules = all subscribers for site
- Verify: Each rule type returns expected results; combined rules use AND logic

**Step 6: Add system segments on site creation**
- File: `app/models/site.rb`
  - Add: `after_create :create_default_subscriber_segments`
  - Private method creates 4 segments with system_segment: true:
    1. "All Subscribers" - rules: `{}`
    2. "Active (30 days)" - rules: `{ "engagement_level": { "min_actions": 1, "within_days": 30 } }`
    3. "New (7 days)" - rules: `{ "subscription_age": { "max_days": 7 } }`
    4. "Power Users" - rules: `{ "referral_count": { "min": 3 } }`
- Verify: New site creation creates 4 SubscriberSegment records with system_segment: true

#### Phase 3: Admin UI (Steps 7-9)

**Step 7: Create SubscriberTagsController**
- File: `app/controllers/admin/subscriber_tags_controller.rb`
  - Include: `AdminAccess`
  - Actions: index, new, create, edit, update, destroy
  - Strong params: `name` only (slug auto-generated)
- File: `config/routes.rb`
  - Add: `resources :subscriber_tags` in admin namespace
- Files: `app/views/admin/subscriber_tags/`
  - `index.html.erb` - Table with name, slug, usage count, actions
  - `new.html.erb` - Form with name field
  - `edit.html.erb` - Form with name field
  - `_form.html.erb` - Shared form partial
- File: `config/locales/en.yml`
  - Add: `admin.subscriber_tags.*` translations
- Verify: Can list, create, edit, delete tags; authorization works

**Step 8: Create SubscriberSegmentsController**
- File: `app/controllers/admin/subscriber_segments_controller.rb`
  - Include: `AdminAccess`
  - Actions: index, show, new, create, edit, update, destroy, preview
  - `show`: Display segment with subscriber count from SegmentationService
  - `preview` (POST): Return count for given rules (AJAX for form preview)
  - `before_action :prevent_system_segment_modification, only: [:edit, :update, :destroy]`
  - Strong params: `name`, `description`, `enabled`, `rules` (as nested hash)
- File: `config/routes.rb`
  - Add: `resources :subscriber_segments` with member `post :preview`
- Files: `app/views/admin/subscriber_segments/`
  - `index.html.erb` - Table with name, type (system/custom), subscriber count, enabled, actions
  - `show.html.erb` - Segment details + matching subscriber count + sample subscribers
  - `new.html.erb` - Form with rule builder
  - `edit.html.erb` - Form with rule builder (disabled for system)
  - `_form.html.erb` - Form with rule builder UI (dropdowns + inputs)
  - `_rules_builder.html.erb` - Stimulus component for dynamic rule building
- File: `config/locales/en.yml`
  - Add: `admin.subscriber_segments.*` translations
- Verify: Can list, view, create, edit, delete custom segments; system segments protected

**Step 9: Add tag assignment to subscribers**
- Option A (inline on segment show): Add tag assignment widget on subscriber segment show page
- Option B (dedicated subscribers list): Create Admin::DigestSubscriptionsController for subscriber management
- Chosen: Option B - More flexible, needed for future features
- File: `app/controllers/admin/digest_subscriptions_controller.rb`
  - Include: `AdminAccess`
  - Actions: index (list), show (detail + tag assignment), update_tags (AJAX)
  - Index: List all subscriptions with search/filter
  - Show: Display subscription details + assignable tags + current tags
  - update_tags: Add/remove tags (respond with turbo_stream or JSON)
- File: `config/routes.rb`
  - Add: `resources :digest_subscriptions, only: [:index, :show] do member { patch :update_tags } end`
- Files: `app/views/admin/digest_subscriptions/`
  - `index.html.erb` - Table with email, frequency, status, tags, referral count
  - `show.html.erb` - Full details + tag checkboxes + engagement stats
- Verify: Can view subscribers; can assign/remove tags; tags persist

#### Phase 4: Digest Integration (Step 10)

**Step 10: Update SendDigestEmailsJob**
- File: `app/jobs/send_digest_emails_job.rb`
  - Update `perform(frequency: "weekly", segment_id: nil)`
  - In `send_weekly_digests` / `send_daily_digests`:
    - If `segment_id` present: Use `SegmentationService.subscribers_for(segment)` as base, then apply frequency scope
    - If `segment_id` nil: Use existing behavior (all subscriptions)
  - Log warning if segment returns 0 subscribers
- Verify: `SendDigestEmailsJob.perform_now(frequency: "weekly", segment_id: segment.id)` sends only to matching subscribers

#### Phase 5: Testing (Steps 11-14)

**Step 11: Write model specs**
- File: `spec/models/subscriber_tag_spec.rb`
  - Validations: name presence, slug format, slug uniqueness per site
  - Associations: subscriber_taggings
  - Callback: slug generation
- File: `spec/models/subscriber_tagging_spec.rb`
  - Validations: uniqueness of pair
  - Associations: digest_subscription, subscriber_tag
- File: `spec/models/subscriber_segment_spec.rb`
  - Validations: name presence
  - Scopes: enabled, system, custom
  - Methods: editable?, rules (returns {})
- File: `spec/factories/subscriber_tags.rb` - Factory
- File: `spec/factories/subscriber_taggings.rb` - Factory
- File: `spec/factories/subscriber_segments.rb` - Factory
- Verify: All model specs pass

**Step 12: Write service spec**
- File: `spec/services/segmentation_service_spec.rb`
  - Test each rule type:
    - subscription_age (min_days, max_days)
    - engagement_level (min_actions, within_days)
    - referral_count (min)
    - tags (any, all)
    - frequency
    - active
  - Test combined rules (AND logic)
  - Test empty rules (returns all)
  - Test no matches (returns empty relation)
  - Test scoping (only current site's subscriptions)
- Verify: All service specs pass

**Step 13: Write request specs**
- File: `spec/requests/admin/subscriber_tags_spec.rb`
  - Test CRUD operations with authentication
  - Test authorization (non-admin rejected)
- File: `spec/requests/admin/subscriber_segments_spec.rb`
  - Test CRUD operations
  - Test system segment protection
  - Test preview action
- File: `spec/requests/admin/digest_subscriptions_spec.rb`
  - Test index, show, update_tags
  - Test tag assignment persistence
- Verify: All request specs pass

**Step 14: Update job spec**
- File: `spec/jobs/send_digest_emails_job_spec.rb`
  - Add tests for segment_id parameter
  - Test: With segment, only matching subscribers receive digest
  - Test: Without segment, existing behavior unchanged
  - Test: Empty segment logs warning, sends nothing
- Verify: All job specs pass

### Checkpoints

| After Step | Verify |
|------------|--------|
| Step 4 | `bin/rails db:migrate` succeeds; all 3 models load; DigestSubscription has tag association |
| Step 6 | `SegmentationService.subscribers_for(segment)` returns correct results for each rule type |
| Step 9 | Admin can manage tags and segments; can assign tags to subscribers |
| Step 10 | `SendDigestEmailsJob.perform_now(segment_id: id)` filters correctly |
| Step 14 | `bundle exec rspec` passes; `bin/rubocop` passes; `bin/brakeman` passes |

### Test Plan

- [ ] **Unit: SubscriberTag** - validations, slug generation, associations
- [ ] **Unit: SubscriberTagging** - uniqueness, associations
- [ ] **Unit: SubscriberSegment** - validations, scopes, editable?
- [ ] **Unit: Site** - system segments created on create
- [ ] **Service: SegmentationService** - all 6 rule types, combined rules, edge cases
- [ ] **Integration: Admin::SubscriberTagsController** - CRUD, authorization
- [ ] **Integration: Admin::SubscriberSegmentsController** - CRUD, preview, system protection
- [ ] **Integration: Admin::DigestSubscriptionsController** - list, show, tag assignment
- [ ] **Job: SendDigestEmailsJob** - segment filtering, fallback behavior

### Docs to Update

- [x] `docs/DATA_MODEL.md` - Added SubscriberSegment, SubscriberTag, SubscriberTagging model documentation
- [x] No README changes needed (internal admin feature)
- [x] AGENTS.md has no model inventory, so no changes needed there

---

## Work Log

### 2026-01-31 00:02 - Verification Complete

Criteria: all met (22/22 acceptance criteria checked)
Quality gates: all pass
- `bin/rubocop`: 0 offenses (563 files)
- `bin/brakeman`: No security warnings
- `bundle exec rspec`: 3659 examples, 0 failures, 1 pending
CI: pass - https://github.com/mitchellfyi/curated.cx/actions/runs/21535001558
- Code Style: ✓
- Security: ✓
- Tests: ✓ (4m30s)
- Build: ✓
- Quality Analysis: ✓

Task location: 3.doing → 4.done
Reason: complete - all criteria met, CI green

---

### 2026-01-31 00:15 - Review Complete

Findings:
- Blockers: 0 - none found
- High: 0 - none found
- Medium: 0 - none found
- Low: 0 - code is clean and well-structured

Review passes:
- Correctness: pass - all logic traces correctly, edge cases handled
- Design: pass - follows existing patterns (SiteScoped, AdminAccess, controller structure)
- Security: pass - proper authorization, tenant isolation, no injection vectors
- Performance: pass - efficient SQL with proper indexes, batched job processing
- Tests: pass - 130 examples covering all functionality, all passing

Key Findings (all positive):
1. **Models**: Clean SiteScoped implementation, proper associations, good validations
2. **SegmentationService**: Pure SQL approach avoids N+1, parameterized queries prevent injection
3. **Controllers**: AdminAccess properly applied, system segment protection working
4. **Job Integration**: Graceful fallback when segment not found, logs warning for empty segments
5. **Tests**: Comprehensive coverage including tenant isolation, authorization, edge cases
6. **Security**: No IDOR - all lookups scoped by site, referral enum values hardcoded correctly (1,2)

Quality Gates:
- `bin/rubocop`: 0 offenses (563 files)
- `bin/brakeman`: No security warnings
- `bundle exec rspec`: 130 new examples, 0 failures

All criteria met: yes
Follow-up tasks: none

Status: COMPLETE

---

### 2026-01-30 23:57 - Documentation Sync

Docs updated:
- `docs/DATA_MODEL.md` - Added SubscriberSegment, SubscriberTag, SubscriberTagging model documentation
- `docs/DATA_MODEL.md` - Updated DigestSubscription associations to include tag relationships

Inline comments:
- `app/services/segmentation_service.rb:1-15` - Existing header comment documents rules format (sufficient)
- `app/models/subscriber_segment.rb:1-29` - Schema annotation auto-generated by annotate gem (sufficient)

Consistency: verified
- SegmentationService header comment matches implementation
- DATA_MODEL.md rules format matches actual JSONB structure
- Model associations documented match code

No README changes needed (internal admin feature, not user-facing).

---

### 2026-01-30 23:32 - Implementation Complete

**Phase 1: Database & Models (Steps 1-4)**
- Created `SubscriberTag` model with migration (`db/migrate/20260130233308_create_subscriber_tags.rb`)
- Created `SubscriberTagging` join model with migration (`db/migrate/20260130233332_create_subscriber_taggings.rb`)
- Created `SubscriberSegment` model with migration (`db/migrate/20260130233355_create_subscriber_segments.rb`)
- Updated `DigestSubscription` with tag associations
- Added `subscriber_segments` and `subscriber_tags` associations to `Site` model
- Verification: `bin/rails db:migrate` succeeded

**Phase 2: Segmentation Service (Steps 5-6)**
- Created `SegmentationService` with rule evaluation for all 6 rule types:
  - `subscription_age` (min_days, max_days)
  - `engagement_level` (min_actions, within_days)
  - `referral_count` (min)
  - `tags` (any, all)
  - `frequency`
  - `active`
- Added `after_create :create_default_subscriber_segments` callback to Site model
- System segments: "All Subscribers", "Active (30 days)", "New (7 days)", "Power Users"
- Verification: Console test confirmed service returns correct count

**Phase 3: Admin UI (Steps 7-9)**
- Created `Admin::SubscriberTagsController` with full CRUD
- Created `Admin::SubscriberSegmentsController` with CRUD + preview action
- Created `Admin::DigestSubscriptionsController` with index, show, update_tags
- Created all views (index, show, new, edit, _form) for all 3 controllers
- Added routes in `config/routes.rb`
- Added locale translations in `config/locales/en.yml`

**Phase 4: Digest Integration (Step 10)**
- Updated `SendDigestEmailsJob.perform` to accept `segment_id` parameter
- Added `subscriptions_scope` method to filter by segment when provided
- Logs warning when segment has no matching subscribers

**Files Created:**
- `app/models/subscriber_tag.rb`
- `app/models/subscriber_tagging.rb`
- `app/models/subscriber_segment.rb`
- `app/services/segmentation_service.rb`
- `app/controllers/admin/subscriber_tags_controller.rb`
- `app/controllers/admin/subscriber_segments_controller.rb`
- `app/controllers/admin/digest_subscriptions_controller.rb`
- `db/migrate/20260130233308_create_subscriber_tags.rb`
- `db/migrate/20260130233332_create_subscriber_taggings.rb`
- `db/migrate/20260130233355_create_subscriber_segments.rb`
- `app/views/admin/subscriber_tags/` (5 files)
- `app/views/admin/subscriber_segments/` (5 files)
- `app/views/admin/digest_subscriptions/` (2 files)

**Files Modified:**
- `app/models/digest_subscription.rb` (added tag associations)
- `app/models/site.rb` (added associations + system segment callback)
- `app/jobs/send_digest_emails_job.rb` (added segment filtering)
- `config/routes.rb` (added admin routes)
- `config/locales/en.yml` (added translations)

**Verification:**
- `bin/rubocop` passes (0 offenses)
- `bin/brakeman` passes (no security warnings)
- `bundle exec rspec spec/models/digest_subscription_spec.rb spec/models/site_spec.rb` passes (64 examples, 0 failures)
- Console tests confirm models and service work correctly

**Not Done (per phase instructions):**
- Tests for new models/service/controllers (Phase 5: Testing)
- Documentation updates (Phase 6: Documentation)

---

### 2026-01-30 23:28 - Planning Complete

**Gap Analysis:**
- 19 criteria assessed: 2 full (frequency, active filters), 2 partial (job, job spec), 15 none (new build)
- Largest gaps: 3 new models, 1 new service, 3 admin controllers, all views

**Risks:**
- Performance on large subscriber lists (mitigated with SQL queries + indexes)
- Bookmark model lacks site_id (mitigated by joining through user_id)
- Empty segment edge case (acceptable - log warning)

**Plan Stats:**
- Steps: 14 (4 models, 2 service, 3 admin UI, 1 job, 4 testing)
- New files: ~25 (3 models, 3 factories, 1 service, 3 controllers, ~10 views, 4 specs)
- Modified files: 4 (DigestSubscription, Site, SendDigestEmailsJob, routes.rb)
- Test coverage: extensive (model, service, request, job specs)

**Key Patterns to Follow:**
- TaggingRule model for rule evaluation structure
- TaggingRulesController for admin controller pattern
- SiteScoped concern for multi-tenant isolation
- Existing admin views for UI consistency

**Implementation Order:**
1. Database/models first (clean foundation)
2. Service second (testable business logic)
3. Admin UI third (user-facing)
4. Job integration fourth (connects everything)
5. Tests throughout (validate each phase)

---

### 2026-01-30 23:27 - Triage Complete

Quality gates:
- Lint: `bin/rubocop`
- Types: missing (Ruby - not applicable)
- Tests: `bundle exec rspec`
- Build: missing (Rails - not applicable, uses `bin/rails`)
- Security: `bin/brakeman`

Task validation:
- Context: clear
- Criteria: specific (22 checkboxes across 6 categories)
- Dependencies: none/satisfied

Complexity:
- Files: many (~15 new files: 3 models, 1 service, 2 controllers, views, migrations, specs)
- Risk: medium (new isolated feature, no breaking changes to existing functionality)

Infrastructure verified:
- `DigestSubscription` model exists with `last_sent_at`, `frequency`, `active`, `preferences` ✓
- `Vote`, `Bookmark`, `ContentView` models exist for engagement tracking ✓
- `Referral` model exists with `confirmed_referrals_count` method ✓
- `TaggingRule` model exists as pattern reference ✓
- `TenantScoped` and `SiteScoped` concerns exist ✓
- `SendDigestEmailsJob` exists and ready for segment filtering ✓

Ready: yes

---

### 2026-01-30 23:22 - Task Expanded

- Intent: BUILD
- Scope: Subscriber segmentation with rule-based filtering, manual tagging, and digest targeting
- Key files to create:
  - `app/models/subscriber_segment.rb`
  - `app/models/subscriber_tag.rb`
  - `app/models/subscriber_tagging.rb`
  - `app/services/segmentation_service.rb`
  - `app/controllers/admin/subscriber_segments_controller.rb`
  - `app/controllers/admin/subscriber_tags_controller.rb`
- Key files to modify:
  - `app/models/digest_subscription.rb` (add tag associations)
  - `app/jobs/send_digest_emails_job.rb` (add segment filtering)
- Complexity: Medium-High (multiple models, service, admin UI, tests)

**Gap Analysis:**

| Requirement | Status | Gap |
|-------------|--------|-----|
| Segment model | None | Build from scratch |
| Tag model | None | Build from scratch |
| Rule evaluation | None | Build service (can follow TaggingRule pattern) |
| Manual tagging | None | Build CRUD + join table |
| Digest filtering | Partial | Add segment_id param to existing job |
| Admin UI | None | Build controllers + views |
| Engagement data | Full | Vote/Bookmark/ContentView exist |
| Referral data | Full | Referral model + method exist |

---

## Testing Evidence

### 2026-01-30 - Phase 4 Testing Complete

**Quality Gates:**
- `bin/rubocop`: ✅ Pass (0 offenses)
- `bin/brakeman`: ✅ Pass (no security warnings)
- `bundle exec rspec`: ✅ Pass (3659 examples, 0 failures, 1 pending)

**Test Files Created:**
- `spec/factories/subscriber_tags.rb` - Factory with :vip and :beta traits
- `spec/factories/subscriber_taggings.rb` - Join factory
- `spec/factories/subscriber_segments.rb` - Factory with system segment traits
- `spec/models/subscriber_tag_spec.rb` - 17 examples (validations, callbacks, associations, scopes)
- `spec/models/subscriber_tagging_spec.rb` - 5 examples (uniqueness, associations)
- `spec/models/subscriber_segment_spec.rb` - 14 examples (validations, scopes, rules, editable?)
- `spec/services/segmentation_service_spec.rb` - 23 examples (all 6 rule types, combined rules, edge cases)
- `spec/requests/admin/subscriber_tags_spec.rb` - 13 examples (CRUD, authorization, tenant isolation)
- `spec/requests/admin/subscriber_segments_spec.rb` - 20 examples (CRUD, system protection, preview)
- `spec/requests/admin/digest_subscriptions_spec.rb` - 18 examples (index, show, update_tags)
- `spec/jobs/send_digest_emails_job_spec.rb` - 15 examples (segment filtering, empty segment, frequency)
- `spec/models/site_spec.rb` - Added 6 examples for system segment creation callback

**Test Coverage by Component:**
| Component | Examples | Status |
|-----------|----------|--------|
| SubscriberTag model | 17 | ✅ |
| SubscriberTagging model | 5 | ✅ |
| SubscriberSegment model | 14 | ✅ |
| Site system segments | 6 | ✅ |
| SegmentationService | 23 | ✅ |
| Admin::SubscriberTagsController | 13 | ✅ |
| Admin::SubscriberSegmentsController | 20 | ✅ |
| Admin::DigestSubscriptionsController | 18 | ✅ |
| SendDigestEmailsJob | 15 | ✅ |
| **Total New Tests** | **131** | ✅ |

**Issues Found and Fixed During Testing:**
1. i18n hardcoded strings in `_form.html.erb` - Fixed with translation keys
2. i18n unused keys (9) - Removed with `i18n-tasks remove-unused`
3. Pagination in DigestSubscriptionsController used unavailable Kaminari - Changed to `.limit(100)`
4. Rubocop spacing offenses in specs - Auto-fixed with `bin/rubocop -A`

**CI Compatibility:** Ready - All tests pass locally with standard RSpec configuration

---

## Notes

**In Scope:**
- SubscriberSegment model with JSONB rules
- SubscriberTag and SubscriberTagging models for manual tagging
- SegmentationService for rule evaluation
- System segments (All, Active, New, Power Users)
- Admin UI for segment and tag management
- Segment filtering in SendDigestEmailsJob
- Full test coverage

**Out of Scope (future tasks):**
- Email open/click tracking (requires webhook integration with email provider)
- Location-based segments (would need IP geolocation, GDPR considerations)
- Dynamic content blocks (different content per segment in same email)
- A/B testing per segment
- Segment analytics dashboard (growth rate, engagement trends)
- Interest-based segments (would need topic preference tracking)
- Bulk subscriber tagging import

**Assumptions:**
- Engagement is measured via existing Vote/Bookmark/ContentView models through user association
- "Active" means the user has any engagement activity in the time window (not email opens)
- Tags are site-scoped (not shared across sites in a tenant)
- Segment rules are evaluated at send time (not cached membership)

**Edge Cases:**
- Subscriber with no engagement data → excluded from engagement-based segments
- Deleted tags → remove tagings but preserve segment rule (rule becomes no-op)
- Empty segment → job runs but sends to 0 subscribers (log warning)
- Overlapping rules → subscriber matches if ALL rule criteria match (AND logic)

**Risks:**
- **Performance**: Evaluating rules for 10k+ subscribers on each send
  - Mitigation: Use efficient SQL queries, not Ruby iteration; add database indexes
- **Stale data**: Engagement data could be old if user account differs from subscription
  - Mitigation: Join through user_id correctly; document this behavior

**Key Files:**
- `app/models/digest_subscription.rb` - Add tag association
- `app/models/subscriber_segment.rb` - New model
- `app/models/subscriber_tag.rb` - New model
- `app/models/subscriber_tagging.rb` - New join model
- `app/services/segmentation_service.rb` - New service
- `app/jobs/send_digest_emails_job.rb` - Add segment param
- `app/controllers/admin/subscriber_segments_controller.rb` - New controller
- `app/controllers/admin/subscriber_tags_controller.rb` - New controller

---

## Links

- Pattern reference: `app/models/tagging_rule.rb` (rule-based evaluation)
- Pattern reference: `app/services/tagging_service.rb` (service pattern)
- Related: `DigestSubscription`, `Vote`, `Bookmark`, `ContentView`, `Referral`
- Competitors: beehiiv segmentation, Kit subscriber scoring
