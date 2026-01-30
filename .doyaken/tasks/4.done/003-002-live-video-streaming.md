# Task: Live Video Streaming Integration

## Metadata

| Field       | Value                                                  |
| ----------- | ------------------------------------------------------ |
| ID          | `003-002-live-video-streaming`                         |
| Status      | `done`                                                 |
| Priority    | `003` Medium                                           |
| Created     | `2026-01-30 15:30`                                     |
| Started     | `2026-01-30 21:13`                                     |
| Completed   | `2026-01-30 21:57`                                     |
| Blocked By  |                                                        |
| Blocks      |                                                        |
| Assigned To | `worker-1` |
| Assigned At | `2026-01-30 21:09` |

---

## Context

**Intent**: BUILD

### Business Context
- **Competitive Feature**: Substack calls live video "the highest-leverage growth tool on the platform right now" because it sends notifications to the entire subscriber list with no algorithm.
- **Platform Evolution**: Substack and beehiiv are evolving into multimedia hubs (podcasts, video).
- **Engagement**: Live video drives real-time engagement and community connection.
- **RICE Score**: 90 (Reach: 300, Impact: 3, Confidence: 75%, Effort: 0.75 person-weeks)

### Problem
Publishers have no way to do live video or webinars within the platform. They must use external tools and manually notify subscribers.

### Solution
Integration with Mux Live for video streaming with built-in subscriber notifications, replay hosting, and live chat via the existing Discussion feature.

### Technical Context (Codebase Analysis)

**Existing Infrastructure to Leverage:**
- `SiteScoped` concern for multi-tenant isolation (all models use this)
- `DigestSubscription` model with `.active` scope for subscriber notifications
- `DigestMailer` pattern for email notifications with configurable from address
- `StripeWebhookHandler` pattern for processing external service webhooks
- `Discussion` model for live chat (already built - `003-001`)
- `Solid Queue` for background job processing
- Pundit policies for authorization
- JSONB settings on `Site` model for per-site configuration
- Turbo Streams for real-time UI updates

**Key Patterns to Follow:**
- Service objects: `StripeCheckoutService`, `StripeWebhookHandler`
- Admin controllers: `Admin::DiscussionsController` with moderation actions
- Background jobs: `SendDigestEmailsJob` with tenant wrapping
- Mailers: `DigestMailer` with dynamic from address
- Models: `Discussion` with SiteScoped, enums, validations

**Provider Decision: Mux**
- Simple RTMP ingestion + HLS playback
- Comprehensive webhooks for stream state changes
- Automatic replay generation
- Reasonable pricing ($0.0041/min live + $0.00018/min VOD)
- Good Ruby SDK support via `mux_ruby` gem

---

## Acceptance Criteria

All must be checked before moving to done:

### Core Model & Database
- [x] `LiveStream` model with: `title`, `description`, `scheduled_at`, `started_at`, `ended_at`, `status` (enum: scheduled/live/ended/archived), `visibility` (enum: public_access/subscribers_only), `mux_stream_id`, `mux_playback_id`, `stream_key`, `replay_url`, `viewer_count`, `peak_viewers`, `site_id`, `user_id`
- [x] `LiveStreamViewer` model for analytics: `live_stream_id`, `user_id`, `joined_at`, `left_at`, `duration_seconds`
- [x] Proper indexes on `site_id`, `status`, `scheduled_at`
- [x] Foreign key constraints with proper cascading

### Mux Integration
- [x] `MuxLiveStreamService` service object following `StripeCheckoutService` pattern
- [x] Create Mux live stream on scheduling (returns stream_key, playback_id)
- [x] Disable/enable stream on demand
- [x] Retrieve playback URLs for embed
- [x] `MuxWebhooksController` + `MuxWebhookHandler` following Stripe pattern
- [x] Handle webhooks: `video.live_stream.active`, `video.live_stream.idle`, `video.asset.ready`

### Publisher Experience (Admin)
- [x] `Admin::LiveStreamsController` with CRUD + start/end actions
- [x] Schedule stream form: title, description, scheduled_at, visibility
- [x] Stream dashboard showing: stream status, viewer count, stream key for OBS
- [x] Manual start/end controls (in addition to auto-detection via webhooks)
- [x] List view of past/upcoming streams

### Subscriber Experience (Viewer)
- [x] `LiveStreamsController#show` for stream playback page
- [x] Mux HLS player embed (using Mux Player or hls.js)
- [x] "Live Now" indicator on site when stream is active
- [x] Associated Discussion for live chat (auto-created with stream)
- [x] Replay playback after stream ends

### Notifications
- [x] `LiveStreamMailer` with `stream_live_notification(subscription, stream)` method
- [x] `NotifyLiveStreamSubscribersJob` following `SendDigestEmailsJob` pattern
- [x] Automatic notification when stream goes live (via webhook)
- [x] Email includes: stream title, direct link, unsubscribe link

### Site Configuration
- [x] `site.setting("streaming.enabled", false)` - feature toggle
- [x] `site.setting("streaming.notify_on_live", true)` - send notifications
- [x] Helper methods: `site.streaming_enabled?`, `site.streaming_notify_on_live?`

### Analytics
- [x] Track viewer joins/leaves via Turbo or polling
- [x] Calculate peak concurrent viewers
- [x] Track total watch time per viewer
- [x] Display stats on admin stream detail page

### Authorization
- [x] `LiveStreamPolicy` with: `show?` (respects visibility), `create?/update?/destroy?` (admin only)
- [x] Rate limiting for stream creation (prevent abuse)

### Testing
- [x] Model specs for `LiveStream`, `LiveStreamViewer`
- [x] Service specs for `MuxLiveStreamService` with mocked API calls
- [x] Request specs for admin and public controllers
- [x] Policy specs for authorization rules
- [x] Factory for `live_stream` with traits `:scheduled`, `:live`, `:ended`

### Quality
- [x] All tests pass
- [x] RuboCop passes
- [x] Brakeman security scan passes
- [x] No N+1 queries
- [x] Changes committed with `[003-002-live-video-streaming]` reference

---

## Plan

### Gap Analysis

| Criterion | Status | Gap |
|-----------|--------|-----|
| `LiveStream` model with all fields | none | Needs full creation with migrations, SiteScoped, enums, validations |
| `LiveStreamViewer` analytics model | none | Needs full creation for viewer tracking |
| Proper indexes and foreign keys | none | Will add in migrations |
| `MuxLiveStreamService` service | none | New service following StripeCheckoutService pattern |
| Mux API integration (create/disable/delete) | none | Needs mux_ruby gem and initializer |
| `MuxWebhooksController` + handler | none | New controller/service following Stripe pattern |
| Webhook handling for stream events | none | Handle active/idle/asset.ready events |
| `Admin::LiveStreamsController` CRUD | none | New admin controller following Discussion pattern |
| Admin views (index/show/new/edit/form) | none | Full admin UI needed |
| Stream dashboard with key display | none | Part of admin show view |
| `LiveStreamsController` public | none | New public controller |
| Mux HLS player embed | none | Frontend integration needed |
| Live Now indicator | none | Component for site-wide display |
| Discussion auto-creation | none | Callback on LiveStream create |
| Replay playback | none | Use Mux asset URL after stream ends |
| `LiveStreamMailer` | none | New mailer following DigestMailer pattern |
| `NotifyLiveStreamSubscribersJob` | none | New job following SendDigestEmailsJob pattern |
| Automatic notification on live | none | Trigger job from webhook handler |
| `site.streaming_enabled?` setting | none | Add to Site model (following discussion pattern) |
| `site.streaming_notify_on_live?` setting | none | Add to Site model |
| Viewer join/leave tracking | none | Turbo or polling endpoint needed |
| Peak viewers calculation | none | Model method to calculate |
| `LiveStreamPolicy` | none | New policy following DiscussionPolicy pattern |
| Rate limiting for stream creation | partial | RateLimitable concern exists, need to apply |
| Model specs | none | Full coverage needed |
| Service specs with mocked API | none | Follow StripeCheckoutService spec pattern |
| Request specs | none | Admin and public controllers |
| Policy specs | none | Authorization rules |
| Factory with traits | none | :scheduled, :live, :ended traits |

### Risks

- [ ] **Mux API costs**: Implement usage monitoring, add warning in admin when approaching limits
- [ ] **Webhook delivery delays**: Poll stream status from admin dashboard as fallback
- [ ] **Notification emails spam-marked**: Use proper List-Unsubscribe headers, respect unsubscribe
- [ ] **Multi-tenant data leak**: SiteScoped on all models, explicit site scoping in queries, test isolation
- [ ] **Stream key exposure**: Never log stream_key, mark as sensitive field
- [ ] **Concurrent viewers overload**: Track in LiveStreamViewer with connection limits per site setting

### Steps

#### Step 1: Mux Gem & Configuration
1. **Add mux_ruby gem**
   - File: `Gemfile`
   - Change: Add `gem "mux_ruby", "~> 3.0"`
   - Verify: `bundle install` succeeds

2. **Create Mux initializer**
   - File: `config/initializers/mux.rb`
   - Change: Configure MuxRuby with ENV credentials (`MUX_TOKEN_ID`, `MUX_TOKEN_SECRET`, `MUX_WEBHOOK_SECRET`)
   - Verify: `rails c` - `MuxRuby.configure` returns config

#### Step 2: Database Migrations
3. **Create live_streams migration**
   - File: `db/migrate/YYYYMMDDHHMMSS_create_live_streams.rb`
   - Change: Create table with columns: `title:string`, `description:text`, `scheduled_at:datetime`, `started_at:datetime`, `ended_at:datetime`, `status:integer(default:0)`, `visibility:integer(default:0)`, `mux_stream_id:string`, `mux_playback_id:string`, `stream_key:string`, `mux_asset_id:string`, `replay_playback_id:string`, `viewer_count:integer(default:0)`, `peak_viewers:integer(default:0)`, `site_id:bigint`, `user_id:bigint`, `discussion_id:bigint`
   - Indexes: `site_id`, `status`, `scheduled_at`, `mux_stream_id` (unique)
   - Foreign keys: `site_id → sites`, `user_id → users`, `discussion_id → discussions`
   - Verify: `rails db:migrate` succeeds

4. **Create live_stream_viewers migration**
   - File: `db/migrate/YYYYMMDDHHMMSS_create_live_stream_viewers.rb`
   - Change: Create table with columns: `live_stream_id:bigint`, `user_id:bigint`, `session_id:string`, `joined_at:datetime`, `left_at:datetime`, `duration_seconds:integer`, `site_id:bigint`
   - Indexes: `[live_stream_id, user_id]` (unique for logged-in), `[live_stream_id, session_id]` (unique for anonymous), `site_id`
   - Foreign keys: `live_stream_id → live_streams`, `user_id → users`, `site_id → sites`
   - Verify: `rails db:migrate` succeeds

#### Step 3: Models
5. **Create LiveStream model**
   - File: `app/models/live_stream.rb`
   - Change: Include SiteScoped, define enums (`status: {scheduled:0, live:1, ended:2, archived:3}`, `visibility: {public_access:0, subscribers_only:1}`), associations (`belongs_to :user`, `belongs_to :site`, `belongs_to :discussion, optional: true`, `has_many :viewers, class_name: 'LiveStreamViewer'`), validations (title required, scheduled_at required), scopes (`:upcoming`, `:live_now`, `:ended`), instance methods (`can_start?`, `can_end?`, `live?`, `replay_url`)
   - Verify: `rails c` - `LiveStream.new` works

6. **Create LiveStreamViewer model**
   - File: `app/models/live_stream_viewer.rb`
   - Change: Include SiteScoped, associations, validations, scopes (`:active` - no left_at), `calculate_duration!` method
   - Verify: `rails c` - `LiveStreamViewer.new` works

#### Step 4: Site Configuration
7. **Add streaming settings to Site model**
   - File: `app/models/site.rb`
   - Change: Add `streaming_enabled?` method returning `setting("streaming.enabled", false)`, add `streaming_notify_on_live?` returning `setting("streaming.notify_on_live", true)`, add config validation for streaming hash
   - Verify: `rails c` - `site.streaming_enabled?` returns false by default

#### Step 5: Mux Service
8. **Create MuxLiveStreamService**
   - File: `app/services/mux_live_stream_service.rb`
   - Change: Constructor takes `site`; methods: `create_stream(title)` → returns `{stream_key, mux_stream_id, mux_playback_id}`, `get_playback_url(playback_id)` → HLS URL, `disable_stream(mux_stream_id)`, `enable_stream(mux_stream_id)`, `delete_stream(mux_stream_id)`, `get_asset(asset_id)` → returns asset with playback_id for replay; include custom error classes `MuxNotConfiguredError`, `MuxApiError`
   - Verify: Service spec with mocked MuxRuby API

#### Step 6: Webhook Handler
9. **Create MuxWebhookHandler service**
   - File: `app/services/mux_webhook_handler.rb`
   - Change: Constructor takes event hash; `process` method routes to: `handle_live_stream_active` (update status to :live, trigger notification job), `handle_live_stream_idle` (update status to :ended if idle > 5min), `handle_asset_ready` (update replay_playback_id from asset); find LiveStream by `mux_stream_id`; wrap updates in transaction
   - Verify: Handler spec with mocked events

10. **Create MuxWebhooksController**
    - File: `app/controllers/mux_webhooks_controller.rb`
    - Change: `skip_before_action :verify_authenticity_token`, `skip_after_action :verify_authorized`, `create` action that: reads payload, verifies Mux signature (HMAC-SHA256), parses JSON, passes to handler, returns 200 on success
    - Verify: Controller responds to POST

11. **Add webhook route**
    - File: `config/routes.rb`
    - Change: Add `post "webhooks/mux", to: "mux_webhooks#create"` near Stripe webhook
    - Verify: `rails routes | grep mux` shows route

#### Step 7: Mailer & Job
12. **Create LiveStreamMailer**
    - File: `app/mailers/live_stream_mailer.rb`
    - Change: `stream_live_notification(subscription, stream)` method following DigestMailer pattern with dynamic from address, set `@stream`, `@subscription`, `@site`, `@user` ivars
    - Verify: Mailer preview at `/rails/mailers/live_stream_mailer`

13. **Create mailer views**
    - Files: `app/views/live_stream_mailer/stream_live_notification.html.erb`, `.text.erb`
    - Change: Template showing stream title, description, "Watch Live" button, unsubscribe link
    - Verify: Preview renders correctly

14. **Create NotifyLiveStreamSubscribersJob**
    - File: `app/jobs/notify_live_stream_subscribers_job.rb`
    - Change: `perform(stream_id)` - find stream, wrap in `ActsAsTenant.with_tenant`, query `DigestSubscription.where(site: stream.site).active.find_each(batch_size: 100)`, call mailer for each, rescue errors per subscriber
    - Verify: Job spec with mocked mailer

#### Step 8: Policy
15. **Create LiveStreamPolicy**
    - File: `app/policies/live_stream_policy.rb`
    - Change: `index?` true, `show?` checks visibility (public or subscriber), `create?/update?/destroy?` admin only + streaming_enabled?, `start?/end?` admin + correct status, Scope class filters by visibility
    - Verify: Policy spec covers all cases

#### Step 9: Admin Controller
16. **Create Admin::LiveStreamsController**
    - File: `app/controllers/admin/live_streams_controller.rb`
    - Change: Include AdminAccess, `before_action :set_live_stream` for member actions, `before_action :check_streaming_enabled` for create, CRUD actions, `start` action (calls MuxLiveStreamService.enable_stream, updates status), `end` action (updates status to ended), auto-create Discussion on create (using visibility match), strong params for title/description/scheduled_at/visibility
    - Verify: Request specs pass

17. **Add admin routes**
    - File: `config/routes.rb`
    - Change: Add in admin namespace: `resources :live_streams do member do post :start; post :end; end end`
    - Verify: `rails routes | grep live_stream` shows admin routes

18. **Create admin views**
    - Files: `app/views/admin/live_streams/index.html.erb`, `show.html.erb`, `new.html.erb`, `edit.html.erb`, `_form.html.erb`
    - Change: Index lists streams with status badges, show displays stream dashboard (status, viewer count, stream key for OBS, playback preview), form with title/description/scheduled_at/visibility inputs
    - Verify: Views render without errors

#### Step 10: Public Controller
19. **Create LiveStreamsController**
    - File: `app/controllers/live_streams_controller.rb`
    - Change: `index` action (policy_scope, live first, then upcoming), `show` action (authorize, increment viewer count), `join` action (create/update LiveStreamViewer), `leave` action (update left_at, calculate duration)
    - Verify: Request specs pass

20. **Add public routes**
    - File: `config/routes.rb`
    - Change: Add `resources :live_streams, only: %i[index show] do member do post :join; post :leave; end end`
    - Verify: Routes exist

21. **Create public views**
    - Files: `app/views/live_streams/index.html.erb`, `show.html.erb`
    - Change: Index shows live/upcoming streams with cards, show embeds Mux Player (HLS.js or @mux/mux-player), includes Discussion posts for live chat, shows replay after ended
    - Verify: Views render, player loads

#### Step 11: Frontend Integration
22. **Add Mux Player JavaScript**
    - File: `package.json` or `app/javascript/`
    - Change: Add `@mux/mux-player` or `hls.js` for HLS playback
    - Verify: `npm run build` succeeds

23. **Create live stream Stimulus controller**
    - File: `app/javascript/controllers/live_stream_controller.js`
    - Change: Connect Mux player, handle join/leave via Turbo or fetch, update viewer count display
    - Verify: Player initializes on stream show page

24. **Create "Live Now" component**
    - File: `app/views/shared/_live_now_indicator.html.erb`
    - Change: Partial that checks `LiveStream.live_now.for_site(Current.site).exists?` and renders indicator with link
    - Verify: Indicator appears when stream is live

#### Step 12: Testing
25. **Create LiveStream factory**
    - File: `spec/factories/live_streams.rb`
    - Change: Factory with user, site associations, traits `:scheduled` (status scheduled), `:live` (status live, started_at set), `:ended` (status ended, ended_at set), `:with_mux` (has mux_stream_id, mux_playback_id, stream_key)
    - Verify: `FactoryBot.build(:live_stream)` works

26. **Create LiveStreamViewer factory**
    - File: `spec/factories/live_stream_viewers.rb`
    - Change: Factory with live_stream, user associations, traits `:active` (no left_at), `:completed` (left_at and duration set)
    - Verify: Factory works

27. **Create model specs**
    - Files: `spec/models/live_stream_spec.rb`, `spec/models/live_stream_viewer_spec.rb`
    - Change: Test associations, validations, enums, scopes, instance methods, site scoping (follow discussion_spec.rb pattern)
    - Verify: `bundle exec rspec spec/models/live_stream*` passes

28. **Create service specs**
    - Files: `spec/services/mux_live_stream_service_spec.rb`, `spec/services/mux_webhook_handler_spec.rb`
    - Change: Mock MuxRuby API calls, test all methods, error handling (follow stripe_checkout_service_spec.rb pattern)
    - Verify: Service specs pass

29. **Create request specs**
    - Files: `spec/requests/admin/live_streams_spec.rb`, `spec/requests/live_streams_spec.rb`, `spec/requests/mux_webhooks_spec.rb`
    - Change: Test CRUD operations, authorization, webhook signature validation
    - Verify: Request specs pass

30. **Create policy specs**
    - File: `spec/policies/live_stream_policy_spec.rb`
    - Change: Test all policy methods for different user types
    - Verify: Policy specs pass

### Checkpoints

| After Step | Verify |
|------------|--------|
| Step 2 (migration) | `rails db:migrate` succeeds, `rails db:rollback` works |
| Step 5 (service) | `MuxLiveStreamService.new(site).create_stream("Test")` returns mock data in console |
| Step 9 (admin) | Admin can create/view/edit streams at `/admin/live_streams` |
| Step 10 (public) | Streams visible at `/live_streams`, player loads on show page |
| Step 12 (testing) | `bundle exec rspec --tag live_stream` passes all tests |

### Test Plan

- [ ] Unit: LiveStream model (validations, enums, scopes, methods)
- [ ] Unit: LiveStreamViewer model (duration calculation, scopes)
- [ ] Unit: MuxLiveStreamService (all API methods with mocked responses)
- [ ] Unit: MuxWebhookHandler (all event types)
- [ ] Integration: Admin CRUD flow (create → view → edit → delete)
- [ ] Integration: Admin start/end stream flow
- [ ] Integration: Webhook processing (simulate Mux events)
- [ ] Integration: Public viewing (join, watch, leave, viewer count)
- [ ] Integration: Notification job (sends to subscribers)
- [ ] Policy: All authorization rules
- [ ] E2E: Full stream lifecycle (schedule → live via webhook → notify → view → end → replay)

### Docs to Update

- [x] `README.md` - Add ENV variables section for MUX_TOKEN_ID, MUX_TOKEN_SECRET, MUX_WEBHOOK_SECRET
- [x] `docs/DATA_MODEL.md` - Add LiveStream and LiveStreamViewer model documentation
- [x] Mux webhook URL documented in code comments (route: POST /webhooks/mux)

---

## Work Log

### 2026-01-30 21:57 - Phase 6 (REVIEW) Complete

**Findings Ledger:**
- Blockers: 0
- High: 0
- Medium: 0
- Low: 1 (deferred) - Query in view pattern for discussion posts could be moved to controller

**Review Passes:**
- Correctness: **PASS** - Happy path and failure paths traced; error handling consistent across all services and controllers
- Design: **PASS** - Follows existing patterns (SiteScoped, StripeWebhookHandler, AdminAccess, DigestMailer)
- Security: **PASS** - OWASP checklist clear:
  - A01 (Access Control): AdminAccess enforced, LiveStreamPolicy respects visibility
  - A02 (Crypto): stream_key not logged, only shown in admin UI
  - A03 (Injection): Parameterized queries via ActiveRecord, no string concatenation
  - A04 (Insecure Design): Webhook signature verification with HMAC-SHA256
  - A09 (Logging): Security events logged without sensitive data
- Performance: **PASS** - N+1 prevented with `includes()` in controllers; minor query-in-view pattern (low)
- Tests: **PASS** - 201 tests covering models, services, controllers, policies; all pass

**Quality Gates:**
- All tests pass: 3333 examples, 0 failures
- RuboCop: No offenses
- Brakeman: No warnings
- Build: Successful

**All Criteria Met:** Yes

**Follow-up Tasks:** None required (low severity issue is acceptable)

**Status:** COMPLETE

---

### 2026-01-30 - Phase 5 (DOCS) Complete

Docs updated:
- `docs/DATA_MODEL.md` - Added LiveStream and LiveStreamViewer model documentation
- `README.md` - Added Mux environment variables section, added MuxLiveStreamService and MuxWebhookHandler to Key Services table

Inline comments:
- Existing code already well-documented with clear comments explaining:
  - `app/services/mux_webhook_handler.rb` - Supported events listed at top
  - `app/services/mux_live_stream_service.rb` - YARD-style method documentation
  - `app/controllers/mux_webhooks_controller.rb` - Signature verification explained
  - `app/jobs/notify_live_stream_subscribers_job.rb` - Error handling rationale

Consistency: Verified - all documentation matches implementation

---

### 2026-01-30 - Phase 4 (TEST) Complete

**Tests Written (201 total):**
- Model specs: `spec/models/live_stream_spec.rb` (59 tests), `spec/models/live_stream_viewer_spec.rb` (22 tests)
- Service specs: `spec/services/mux_live_stream_service_spec.rb` (17 tests), `spec/services/mux_webhook_handler_spec.rb` (15 tests)
- Request specs: `spec/requests/admin/live_streams_spec.rb` (29 tests), `spec/requests/live_streams_spec.rb` (14 tests), `spec/requests/mux_webhooks_spec.rb` (9 tests)
- Policy specs: `spec/policies/live_stream_policy_spec.rb` (36 tests)

**Factories Created:**
- `spec/factories/live_streams.rb` - with traits `:scheduled`, `:live`, `:ended`, `:archived`, `:with_mux`, `:with_replay`, `:subscribers_only`
- `spec/factories/live_stream_viewers.rb` - with traits `:active`, `:completed`, `:anonymous`

**Bug Fixes Discovered During Testing:**
- Fixed `LiveStreamsController` missing `skip_after_action :verify_authorized, only: [:index]`
- Removed 6 unused i18n keys from `config/locales/en.yml`

**Quality Gates:**
- Lint: RuboCop passed (514 files, no offenses)
- Tests: 3333 examples, 0 failures, 1 pending
- Build: `npm run build` and `npm run build:css` successful
- Security: Brakeman passed (0 warnings)

**Commit:** `0534078 test: Add comprehensive tests for live video streaming feature [003-002-live-video-streaming]`

---

### 2026-01-30 21:19 - Implementation Complete

**Files Created:**
- `Gemfile` - Added `mux_ruby` gem
- `config/initializers/mux.rb` - Mux API configuration
- `db/migrate/20260130212037_create_live_streams.rb` - LiveStream table
- `db/migrate/20260130212038_create_live_stream_viewers.rb` - LiveStreamViewer table
- `app/models/live_stream.rb` - LiveStream model with SiteScoped, enums, scopes
- `app/models/live_stream_viewer.rb` - LiveStreamViewer model for analytics
- `app/services/mux_live_stream_service.rb` - Mux API service
- `app/services/mux_webhook_handler.rb` - Mux webhook event handler
- `app/controllers/mux_webhooks_controller.rb` - Mux webhook endpoint
- `app/controllers/admin/live_streams_controller.rb` - Admin CRUD + start/end
- `app/controllers/live_streams_controller.rb` - Public viewing + join/leave
- `app/mailers/live_stream_mailer.rb` - Notification mailer
- `app/views/live_stream_mailer/` - Email templates (HTML + text)
- `app/jobs/notify_live_stream_subscribers_job.rb` - Batch notification job
- `app/policies/live_stream_policy.rb` - Authorization policy
- `app/views/admin/live_streams/` - Admin views (index, show, new, edit, form)
- `app/views/live_streams/` - Public views (index, show, card partial)
- `app/views/shared/_live_now_indicator.html.erb` - Live now badge
- `app/javascript/controllers/live_stream_controller.js` - Stimulus controller

**Files Modified:**
- `app/models/site.rb` - Added streaming settings + associations
- `config/routes.rb` - Added admin and public routes + webhook
- `config/locales/en.yml` - Added I18n translations
- `app/javascript/controllers/index.js` - Registered live_stream controller
- `package.json` - Added @mux/mux-player

**Verification:**
- RuboCop: 10 files inspected, no offenses
- Bundle install: successful
- Rails db:migrate: successful (rollback tested)
- npm run build: successful
- Routes: All 14 live_stream routes verified

**Acceptance Criteria Progress:**
- [x] LiveStream model with all fields, enums, associations
- [x] LiveStreamViewer model for analytics
- [x] Proper indexes and foreign keys
- [x] MuxLiveStreamService service object
- [x] MuxWebhooksController + MuxWebhookHandler
- [x] Admin::LiveStreamsController with CRUD + start/end
- [x] Admin views with stream dashboard
- [x] LiveStreamsController for public viewing
- [x] Mux Player embed via @mux/mux-player
- [x] Live Now indicator partial
- [x] Associated Discussion auto-created with stream
- [x] LiveStreamMailer with notification template
- [x] NotifyLiveStreamSubscribersJob following pattern
- [x] Site streaming settings (streaming_enabled?, streaming_notify_on_live?)
- [x] Viewer join/leave tracking via Stimulus controller
- [x] Peak viewers calculation in model
- [x] LiveStreamPolicy with visibility checks

**Remaining (Next Phase - Testing):**
- [ ] Model specs for LiveStream, LiveStreamViewer
- [ ] Service specs for MuxLiveStreamService, MuxWebhookHandler
- [ ] Request specs for controllers
- [ ] Policy specs for authorization
- [ ] Factories with traits

---

### 2026-01-30 21:14 - Planning Complete

**Codebase Analysis:**
- Explored SiteScoped concern at `app/models/concerns/site_scoped.rb` - auto-scopes by Current.site
- Reviewed StripeCheckoutService (`app/services/stripe_checkout_service.rb`) - pattern for external API integration with error classes
- Reviewed StripeWebhookHandler (`app/services/stripe_webhook_handler.rb`) - event routing, transactions, job queuing
- Reviewed Discussion model (`app/models/discussion.rb`) - SiteScoped, enums with prefix, visibility pattern
- Reviewed DigestMailer (`app/mailers/digest_mailer.rb`) - dynamic from address pattern
- Reviewed SendDigestEmailsJob (`app/jobs/send_digest_emails_job.rb`) - batch processing with ActsAsTenant wrapper
- Reviewed Admin::DiscussionsController - AdminAccess concern, member actions for state changes
- Reviewed DiscussionPolicy - visibility checks, subscriber access pattern
- Reviewed Site model - JSONB settings with `setting(key, default)` pattern

**Gap Analysis:**
- All 27 acceptance criteria require new implementation (none exist)
- Existing patterns are mature and well-tested - follow strictly

**Plan Summary:**
- Steps: 30
- Risk mitigations: 6
- Test coverage: extensive (unit, integration, policy, E2E)
- New files: ~25 (models, services, controllers, views, mailer, job, policy, specs, factories)
- Modified files: 3 (Gemfile, routes.rb, site.rb)

**Critical Patterns Identified:**
1. SiteScoped required on all models for multi-tenant isolation
2. ActsAsTenant.with_tenant wrapper required in background jobs
3. Follow StripeWebhookHandler for Mux webhook processing
4. Use Discussion model's visibility enum pattern
5. Never log stream_key (sensitive credential)

---

### 2026-01-30 21:13 - Triage Complete

Quality gates:
- Lint: `bundle exec rubocop` (Ruby), `npm run lint` (JS)
- Types: N/A (Ruby, no type checking configured)
- Tests: `bundle exec rspec`
- Build: `npm run build && npm run build:css`
- Security: `bundle exec brakeman`

Task validation:
- Context: clear - business context, technical context, and provider decision well documented
- Criteria: specific - 27 acceptance criteria with detailed requirements
- Dependencies: satisfied - `003-001-community-chat-discussions` is complete in `4.done/`, Discussion model exists with SiteScoped and full implementation

Complexity:
- Files: many (15+ new files across models, controllers, services, views, jobs, mailers, policies)
- Risk: high
  - External API integration (Mux) with webhooks
  - Real-time features (player, viewer tracking)
  - Email notifications at scale
  - Multi-tenant isolation critical

Notes:
- manifest.yaml quality commands are empty but Rails standard tools are available (rubocop, rspec, brakeman)
- mux_ruby gem needs to be added to Gemfile
- Mux API credentials needed: `MUX_TOKEN_ID`, `MUX_TOKEN_SECRET`

Ready: yes

---

### 2026-01-30 21:09 - Task Expanded

- **Intent**: BUILD
- **Scope**: Full live video streaming integration with Mux, notifications, and replay
- **Key Files to Create**:
  - `app/models/live_stream.rb`, `app/models/live_stream_viewer.rb`
  - `app/services/mux_live_stream_service.rb`, `app/services/mux_webhook_handler.rb`
  - `app/controllers/admin/live_streams_controller.rb`, `app/controllers/live_streams_controller.rb`
  - `app/controllers/mux_webhooks_controller.rb`
  - `app/mailers/live_stream_mailer.rb`
  - `app/jobs/notify_live_stream_subscribers_job.rb`
  - `app/policies/live_stream_policy.rb`
- **Key Files to Modify**:
  - `app/models/site.rb` (add streaming settings helpers)
  - `config/routes.rb` (add routes)
  - `Gemfile` (add `mux_ruby` gem)
- **Complexity**: HIGH
  - External API integration (Mux)
  - Real-time features (player, viewer tracking)
  - Webhook handling
  - Email notifications at scale
  - Multi-tenant isolation requirements

---

## Testing Evidence

```
$ bundle exec rspec
...
3333 examples, 0 failures, 1 pending

$ bundle exec rubocop
Inspecting 514 files
...
514 files inspected, no offenses detected

$ bundle exec brakeman -q --no-pager
No warnings found

$ npm run build
✓ build completed

$ npm run build:css
✓ build:css completed
```

---

## Notes

### In Scope
- LiveStream model with full lifecycle (scheduled → live → ended → archived)
- Mux integration for stream management and playback
- Webhook handling for stream state changes
- Email notifications when going live
- Admin UI for managing streams
- Public viewer experience with player embed
- Integration with existing Discussion feature for live chat
- Basic analytics (viewer count, peak concurrent, duration)
- Per-site feature toggle

### Out of Scope (Future Enhancements)
- Automatic clip creation (like Substack highlights)
- Multi-host streams / guest invites
- Screen sharing within platform
- Paid/premium-only streams
- Recording download for publishers
- Push notifications (mobile/browser)
- Stream scheduling calendar view
- Simulcast to YouTube/Twitch
- Custom RTMP destinations
- Transcoding quality options

### Assumptions
- Publishers will use external software (OBS, Streamyard) to broadcast via RTMP
- Mux API credentials will be provided as ENV variables (`MUX_TOKEN_ID`, `MUX_TOKEN_SECRET`)
- Webhook endpoint will be publicly accessible for Mux callbacks
- One stream at a time per site (no concurrent streams)
- Discussion feature is already implemented and working (`003-001`)

### Edge Cases

| Case | Handling |
|------|----------|
| Stream scheduled but never goes live | Auto-archive after 24h past scheduled time |
| Publisher disconnects mid-stream | Mux sends `idle` webhook → mark as paused, auto-end after 5 min |
| Viewer joins after stream ends | Show replay if available, or "stream ended" message |
| Large subscriber list (10k+) | Batch notifications via Solid Queue, rate limit to avoid email provider limits |
| Site streaming disabled mid-stream | Allow current stream to continue, prevent new streams |
| Mux API failure during stream creation | Return error to admin, log for debugging, don't create partial record |
| Webhook signature validation fails | Reject request, log warning |

### Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Mux API costs higher than expected | Medium | Medium | Implement usage monitoring, set alerts |
| Webhook delivery delays | Low | Medium | Implement polling fallback for critical state changes |
| Notification emails marked as spam | Medium | High | Use proper email headers, respect unsubscribe |
| Video player compatibility issues | Low | Medium | Use Mux's official player component |
| Multi-tenant data leak | Low | Critical | SiteScoped on all models, test isolation |

### Technical Decisions

**Why Mux over alternatives:**
- **vs Cloudflare Stream**: Mux has better live streaming focus, more mature webhooks
- **vs YouTube Live API**: Mux doesn't require YouTube account, better white-label experience
- **vs Self-hosted (FFmpeg/Nginx-RTMP)**: Mux handles encoding, CDN, player - significantly less infra

**Player choice:** Mux Player (official) or hls.js as fallback - both support HLS natively

---

## Links

- [Mux Live Streaming Docs](https://docs.mux.com/guides/video/start-live-streaming)
- [Mux Ruby SDK](https://github.com/muxinc/mux-ruby)
- [Mux Webhooks Reference](https://docs.mux.com/guides/video/listen-for-webhooks)
- Related task: `003-001-community-chat-discussions` (Discussion feature for live chat)
