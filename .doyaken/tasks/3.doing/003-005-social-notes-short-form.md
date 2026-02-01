# Task: Social Notes / Short-Form Content

## Metadata

| Field       | Value                                                  |
| ----------- | ------------------------------------------------------ |
| ID          | `003-005-social-notes-short-form`                      |
| Status      | `doing`                                                |
| Priority    | `003` Medium                                           |
| Created     | `2026-01-30 15:30`                                     |
| Started     | `2026-02-01 17:00`                                     |
| Completed   |                                                        |
| Blocked By  |                                                        |
| Blocks      |                                                        |
| Assigned To | `worker-1` |
| Assigned At | `2026-02-01 17:55` |

---

## Context

**Intent**: BUILD

Why does this task exist? What problem does it solve?

- **Competitive Feature**: Substack Notes is the #1 growth source, driving 70% of new subscribers for some creators. It's a social layer on top of the newsletter platform.
- **Platform Trend**: Content platforms are adding social features to increase engagement and discoverability.
- **Network Effect**: Short-form content shared across the network drives discovery.
- **RICE Score**: 90 (Reach: 500, Impact: 2, Confidence: 75%, Effort: 0.83 person-weeks)

**Problem**: Publishers can only share long-form content items (curated links from external sources). There's no quick way to share original thoughts, links, or quick updates with their audience.

**Solution**: A "Note" model for short-form posts that appear in a social feed, can be shared across the network, and drive subscriber growth. Unlike ContentItem (which is for curated/ingested external content), Notes are original short-form content authored directly by users.

**Codebase Context**:
- Existing patterns to follow: `ContentItem`, `Comment`, `Vote`, `Bookmark` models all use `SiteScoped` concern
- Multi-tenancy: All models scoped to `site_id`, use `Current.site` context
- Engagement: `Vote` uses `counter_cache: :upvotes_count`, polymorphic `Bookmark`
- Feed: `NetworkFeedService` aggregates content across enabled sites
- Digest: `DigestMailer` fetches top content for weekly/daily emails
- Moderation: `Flag` model is polymorphic (`flaggable`), `hidden_at`/`hidden_by` pattern
- Image attachments: Active Storage available but not heavily used; `raw_payload` JSONB for metadata
- Link previews: `MetaInspector` gem used in `ScrapeMetadataJob`

---

## Acceptance Criteria

All must be checked before moving to done:

### Data Model
- [ ] `Note` model with `body` (text, max 500 chars), `user_id`, `site_id`
- [ ] Counter caches: `upvotes_count`, `comments_count`
- [ ] Status fields: `published_at`, `hidden_at`, `hidden_by_id`
- [ ] Self-referential `repost_of_id` for reposts with attribution
- [ ] JSONB `link_preview` field for OG metadata (title, description, image, url)
- [ ] Optional Active Storage `has_one_attached :image`
- [ ] Database indices: `(site_id, published_at DESC)`, `(user_id, created_at DESC)`, `(repost_of_id)`

### Core Functionality
- [ ] CRUD operations for notes (create, read, update, destroy)
- [ ] Publishing flow: notes can be drafts (`published_at: nil`) or published
- [ ] Character limit validation (500 chars max for body)
- [ ] Link detection and automatic OG metadata extraction via `LinkPreviewService`
- [ ] Image upload support (single image per note)

### Engagement
- [ ] Voting on notes (extend `Vote` to support polymorphic `votable` OR create dedicated `NoteVote`)
- [ ] Comments on notes (extend `Comment` to support polymorphic OR create `NoteComment`)
- [ ] Bookmarks on notes (already polymorphic, just add `Note` support)

### Feeds
- [ ] Publisher's notes feed at `/notes` on each tenant site
- [ ] Single note permalink at `/notes/:id`
- [ ] User's notes profile section
- [ ] Network-wide notes feed on curated.cx hub via `NetworkFeedService.recent_notes`

### Reposts
- [ ] Repost a note to your own site with attribution
- [ ] Original author attribution displayed on reposts
- [ ] Repost count tracked on original note (`reposts_count` counter cache)

### Digest Integration
- [ ] Notes included in weekly/daily digest emails (publisher preference)
- [ ] `DigestMailer` fetches top notes alongside content items
- [ ] Site setting to enable/disable notes in digest

### Authorization & Moderation
- [ ] `NotePolicy` for Pundit authorization
- [ ] Only editors+ can create notes (consistent with ContentItem)
- [ ] Users can only edit/delete their own notes (or admins)
- [ ] Hide/unhide notes (moderation) using existing `hidden_at` pattern
- [ ] `Flag` support for reporting notes (polymorphic `flaggable`)
- [ ] Rate limiting: 10 notes/hour per user

### Tests
- [ ] Model specs: validations, associations, scopes
- [ ] Request specs: CRUD, voting, commenting
- [ ] Policy specs: authorization rules
- [ ] Service specs: LinkPreviewService
- [ ] Feature specs: create note, repost flow

### Quality
- [ ] Quality gates pass (lint, type check, tests, build)
- [ ] Changes committed with task reference `[003-005-social-notes-short-form]`

---

## Plan

### Gap Analysis

| Criterion | Status | Gap |
|-----------|--------|-----|
| Note model with body, user_id, site_id | none | Need to create model and migration |
| Counter caches (upvotes_count, comments_count) | none | Need columns in notes table |
| Status fields (published_at, hidden_at, hidden_by_id) | none | Need columns in notes table |
| Self-referential repost_of_id | none | Need column and association |
| JSONB link_preview field | none | Need column |
| Active Storage image attachment | none | Need `has_one_attached :image` |
| Database indices | none | Need to add in migration |
| CRUD operations | none | Need controller and views |
| Publishing flow (draft/published) | none | Need scopes and logic |
| Character limit validation | none | Need validates :body, length |
| Link detection + OG extraction | none | Need LinkPreviewService |
| Image upload | none | Need form handling |
| Voting on notes | partial | Vote is NOT polymorphic - needs migration to add `votable_type`/`votable_id` |
| Comments on notes | partial | Comment is NOT polymorphic - needs migration to add `commentable_type`/`commentable_id` |
| Bookmarks on notes | full | Bookmark is already polymorphic (`bookmarkable_type`/`bookmarkable_id`) |
| Notes feed at /notes | none | Need routes, controller, views |
| Note permalink /notes/:id | none | Need show action |
| User profile notes section | none | Need profile controller update |
| Network feed notes | none | Need NetworkFeedService.recent_notes method |
| Repost functionality | none | Need repost_of association and controller action |
| Digest integration | none | Need DigestMailer.fetch_top_notes method |
| NotePolicy | none | Need new policy file |
| Editor+ create permission | none | Need policy implementation |
| Hide/unhide moderation | none | Need hide!/unhide! methods |
| Flag support | full | Flag is already polymorphic (`flaggable_type`/`flaggable_id`) |
| Rate limiting | partial | RateLimitable concern exists, need to add `:note` action |
| Tests | none | Need all test files |

### Risks

- [x] **Polymorphic Vote migration**: Medium likelihood, HIGH impact. Vote currently has `content_item_id` column with foreign key. Need reversible migration that:
  1. Adds `votable_type` and `votable_id` columns
  2. Backfills existing votes with `votable_type: 'ContentItem'` and `votable_id: content_item_id`
  3. Removes `content_item_id` column
  4. Updates unique index from `(site_id, user_id, content_item_id)` to `(site_id, user_id, votable_type, votable_id)`
  - **Mitigation**: Write migration first, test thoroughly on staging, ensure reversibility

- [x] **Polymorphic Comment migration**: Medium likelihood, HIGH impact. Same pattern as Vote - has `content_item_id` with foreign key.
  - **Mitigation**: Same approach as Vote migration

- [x] **Comment threading validation**: Comment.parent_belongs_to_same_content_item validation checks `content_item_id`. After polymorphic change, need to update to check `commentable` instead.
  - **Mitigation**: Update validation method when making Comment polymorphic

- [ ] **Counter cache with polymorphic**: Counter cache on polymorphic associations requires careful handling - need to specify counter cache on both ContentItem and Note.
  - **Mitigation**: Test counter increment/decrement after migration

- [ ] **Existing controller coupling**: VotesController and CommentsController are coupled to ContentItem. Need to either:
  - (A) Make them polymorphic (single controller handles both) - MORE COMPLEX
  - (B) Create separate NoteVotesController and NoteCommentsController - SIMPLER
  - **Decision**: Use approach (B) - separate controllers to minimize risk to existing functionality

### Steps

#### Phase 1: Data Model (Steps 1-3)

1. **Create Note migration**
   - File: `db/migrate/YYYYMMDDHHMMSS_create_notes.rb`
   - Change: Create notes table with all columns:
     ```ruby
     create_table :notes do |t|
       t.references :site, null: false, foreign_key: true
       t.references :user, null: false, foreign_key: true
       t.references :hidden_by, foreign_key: { to_table: :users }
       t.references :repost_of, foreign_key: { to_table: :notes }
       t.text :body, null: false
       t.jsonb :link_preview, default: {}
       t.datetime :published_at
       t.datetime :hidden_at
       t.integer :upvotes_count, default: 0, null: false
       t.integer :comments_count, default: 0, null: false
       t.integer :reposts_count, default: 0, null: false
       t.timestamps
     end
     add_index :notes, [:site_id, :published_at], order: { published_at: :desc }
     add_index :notes, [:user_id, :created_at], order: { created_at: :desc }
     add_index :notes, :repost_of_id
     add_index :notes, :hidden_at
     ```
   - Verify: `rails db:migrate` succeeds

2. **Create Note model**
   - File: `app/models/note.rb`
   - Change: Create model with SiteScoped, validations, associations, scopes
   - Verify: `Note` class loads, `Note.new.valid?` shows expected errors

3. **Add Note associations to User and Site**
   - File: `app/models/user.rb` - add `has_many :notes, dependent: :destroy`
   - File: `app/models/site.rb` - add `has_many :notes, dependent: :destroy`
   - Verify: `rails c` - associations work

#### Phase 2: Polymorphic Migrations (Steps 4-5) - HIGH RISK

4. **Make Vote polymorphic**
   - File: `db/migrate/YYYYMMDDHHMMSS_make_votes_polymorphic.rb`
   - Change:
     1. Add `votable_type` (string) and `votable_id` (bigint) columns
     2. Backfill: `UPDATE votes SET votable_type='ContentItem', votable_id=content_item_id`
     3. Add NOT NULL constraints to new columns
     4. Remove old index `index_votes_uniqueness`
     5. Add new index `(site_id, user_id, votable_type, votable_id)` UNIQUE
     6. Remove `content_item_id` column (and its foreign key)
   - File: `app/models/vote.rb` - change to polymorphic:
     ```ruby
     belongs_to :votable, polymorphic: true
     validates :user_id, uniqueness: { scope: %i[site_id votable_type votable_id] }
     scope :for_content_item, ->(item) { where(votable: item) }
     scope :for_note, ->(note) { where(votable: note) }
     ```
   - File: `app/models/content_item.rb` - update association:
     ```ruby
     has_many :votes, as: :votable, dependent: :destroy
     ```
   - Verify: Existing vote tests pass, `ContentItem.first.votes` works

5. **Make Comment polymorphic**
   - File: `db/migrate/YYYYMMDDHHMMSS_make_comments_polymorphic.rb`
   - Change: Same pattern as Vote migration
   - File: `app/models/comment.rb` - change to polymorphic:
     ```ruby
     belongs_to :commentable, polymorphic: true
     # Update parent validation to use commentable instead of content_item
     def parent_belongs_to_same_commentable
       return unless parent.present?
       if parent.commentable_type != commentable_type || parent.commentable_id != commentable_id
         errors.add(:parent, "must belong to the same #{commentable_type.underscore.humanize}")
       end
     end
     ```
   - File: `app/models/content_item.rb` - update association:
     ```ruby
     has_many :comments, as: :commentable, dependent: :destroy
     ```
   - Verify: Existing comment tests pass, threading validation works

#### Phase 3: Engagement Associations (Steps 6-7)

6. **Add Bookmark support for Notes**
   - File: `app/models/note.rb` - add `has_many :bookmarks, as: :bookmarkable, dependent: :destroy`
   - File: `app/models/bookmark.rb` - add `scope :notes, -> { where(bookmarkable_type: "Note") }`
   - Verify: `Bookmark.notes` scope works

7. **Add Flag support for Notes**
   - File: `app/models/note.rb` - add `has_many :flags, as: :flaggable, dependent: :destroy`
   - File: `app/models/flag.rb` - add `scope :for_notes, -> { where(flaggable_type: "Note") }`
   - Verify: Notes can be flagged

#### Phase 4: Services (Steps 8-9)

8. **Create LinkPreviewService**
   - File: `app/services/link_preview_service.rb`
   - Change: Create service using MetaInspector (pattern from `ScrapeMetadataJob`)
   - Methods: `extract(url)` returns hash with title, description, image, site_name, url
   - Verify: `LinkPreviewService.extract("https://example.com")` returns hash

9. **Create ExtractNoteLinkPreviewJob**
   - File: `app/jobs/extract_note_link_preview_job.rb`
   - Change: Background job that:
     1. Finds first URL in note body using regex
     2. Calls LinkPreviewService.extract
     3. Updates note.link_preview
   - Verify: Job extracts and stores link preview

#### Phase 5: Authorization (Step 10)

10. **Create NotePolicy**
    - File: `app/policies/note_policy.rb`
    - Change: Create policy following ContentItemPolicy pattern:
      - `index?` - public (unless tenant requires login)
      - `show?` - public for published notes
      - `create?` - editors+ (admin_or_editor?)
      - `update?` - own note or admin
      - `destroy?` - own note or admin
      - `hide?`/`unhide?` - admins only
    - Verify: Policy specs pass

#### Phase 6: Controller & Routes (Steps 11-12)

11. **Create NotesController**
    - File: `app/controllers/notes_controller.rb`
    - Change: Create controller with:
      - `include RateLimitable, BanCheckable`
      - CRUD actions (index, show, new, create, edit, update, destroy)
      - `repost` action for reposts
      - Rate limiting: 10 notes/hour (add to LIMITS)
    - Verify: Controller loads, actions respond

12. **Add note routes**
    - File: `config/routes.rb`
    - Change: Add routes after content_items block:
      ```ruby
      resources :notes do
        post :vote, to: "note_votes#toggle", on: :member
        post :repost, on: :member
        resources :comments, controller: "note_comments", only: %i[index create update destroy]
      end
      ```
    - Verify: `rails routes | grep notes` shows expected routes

#### Phase 7: Note Voting & Commenting (Steps 13-14)

13. **Create NoteVotesController**
    - File: `app/controllers/note_votes_controller.rb`
    - Change: Create controller following VotesController pattern but for notes
    - Verify: Toggle vote on note works

14. **Create NoteCommentsController**
    - File: `app/controllers/note_comments_controller.rb`
    - Change: Create controller following CommentsController pattern but for notes
    - Verify: Create/update/delete comments on notes works

#### Phase 8: Views (Steps 15-17)

15. **Create note views**
    - Files: `app/views/notes/index.html.erb`, `show.html.erb`, `new.html.erb`, `edit.html.erb`
    - Change: Create views following ContentItem/Feed patterns
    - Verify: Views render

16. **Create note partials**
    - File: `app/views/notes/_note.html.erb` - single note card
    - File: `app/views/notes/_form.html.erb` - create/edit form
    - File: `app/views/note_votes/_vote_button.html.erb` - vote button
    - Verify: Partials render

17. **Create note Turbo streams**
    - File: `app/views/note_comments/create.turbo_stream.erb`
    - File: `app/views/note_votes/toggle.turbo_stream.erb`
    - Verify: Turbo stream responses work

#### Phase 9: Network Feed (Steps 18-19)

18. **Extend NetworkFeedService**
    - File: `app/services/network_feed_service.rb`
    - Change: Add `recent_notes` method following `recent_content` pattern
    - Change: Add notes count to `network_stats`
    - Verify: `NetworkFeedService.recent_notes(tenant: Tenant.root)` works

19. **Update hub to show notes**
    - File: `app/controllers/tenants_controller.rb` (or hub controller)
    - File: `app/views/tenants/show.html.erb` (or hub view)
    - Change: Add network notes section to hub page
    - Verify: Notes appear on curated.cx homepage

#### Phase 10: Digest Integration (Steps 20-21)

20. **Add notes to DigestMailer**
    - File: `app/mailers/digest_mailer.rb`
    - Change: Add `fetch_top_notes` method, add `@notes` to weekly/daily methods
    - Verify: Digest methods include notes

21. **Add digest notes setting**
    - File: `app/models/site.rb` - add `notes_in_digest?` helper
    - File: `app/mailers/digest_mailer.rb` - check setting
    - Change: Site config `config['digest']['include_notes']` (default true)
    - Verify: Setting controls notes in digest

#### Phase 11: Rate Limiting (Step 22)

22. **Add note rate limit**
    - File: `app/models/concerns/rate_limitable.rb`
    - Change: Add `note: { limit: 10, period: 1.hour }` to LIMITS hash
    - Verify: Rate limiting works for notes

#### Phase 12: Testing (Steps 23-27)

23. **Model specs**
    - File: `spec/models/note_spec.rb`
    - Coverage: validations, associations, scopes, repost?, published?, hidden?, hide!, unhide!

24. **Request specs**
    - File: `spec/requests/notes_spec.rb`
    - Coverage: CRUD, repost, permissions

25. **Policy specs**
    - File: `spec/policies/note_policy_spec.rb`
    - Coverage: index?, show?, create?, update?, destroy?, hide?, unhide?

26. **Service specs**
    - File: `spec/services/link_preview_service_spec.rb`
    - Coverage: success, timeout, invalid URL

27. **Job specs**
    - File: `spec/jobs/extract_note_link_preview_job_spec.rb`
    - Coverage: extracts URL, handles no URL, handles errors

### Checkpoints

| After Step | Verify |
|------------|--------|
| Step 3 | `Note.create!(site: Site.first, user: User.first, body: "test")` works |
| Step 5 | All existing Vote and Comment tests pass |
| Step 10 | NotePolicy specs pass |
| Step 12 | `rails routes | grep notes` shows all expected routes |
| Step 14 | Can create comment on note via controller |
| Step 17 | Turbo stream responses render correctly |
| Step 19 | Notes appear on curated.cx hub page |
| Step 21 | Digest emails include/exclude notes based on setting |
| Step 27 | All tests pass, quality gates pass |

### Test Plan

- [ ] **Unit: Note model** - validations, associations, scopes, instance methods
- [ ] **Unit: Vote (updated)** - polymorphic association works for both ContentItem and Note
- [ ] **Unit: Comment (updated)** - polymorphic association works, threading validation updated
- [ ] **Unit: LinkPreviewService** - success, timeout, invalid URL, network errors
- [ ] **Integration: NotesController** - CRUD, repost, authorization
- [ ] **Integration: NoteVotesController** - toggle, rate limiting
- [ ] **Integration: NoteCommentsController** - CRUD, threading
- [ ] **Integration: NetworkFeedService** - recent_notes, network_stats
- [ ] **Integration: DigestMailer** - includes notes when enabled
- [ ] **Policy: NotePolicy** - all methods
- [ ] **Feature: Create note flow** - end-to-end with image upload
- [ ] **Feature: Repost flow** - repost attribution displays

### Docs to Update

- [ ] `app/models/vote.rb` - update schema comment header after polymorphic migration
- [ ] `app/models/comment.rb` - update schema comment header after polymorphic migration
- [ ] Site config documentation - add `digest.include_notes` setting

---

## Work Log

### 2026-02-01 - Planning Complete

**Gap Analysis Summary:**
- Full: 2 items (Bookmark, Flag - already polymorphic)
- Partial: 3 items (Vote, Comment, RateLimitable - need modifications)
- None: 23 items (need to be built)

**Key Findings from Codebase Exploration:**
- `Vote` model (app/models/vote.rb:28) - NOT polymorphic, has `content_item_id` FK
- `Comment` model (app/models/comment.rb:33) - NOT polymorphic, has `content_item_id` FK
- `Bookmark` model (app/models/bookmark.rb:24) - IS polymorphic (`bookmarkable_type`/`bookmarkable_id`)
- `Flag` model (app/models/flag.rb:35) - IS polymorphic (`flaggable_type`/`flaggable_id`)
- `RateLimitable` concern (app/models/concerns/rate_limitable.rb:16) - Controller concern, has LIMITS hash
- `ScrapeMetadataJob` (app/jobs/scrape_metadata_job.rb:4) - MetaInspector pattern to follow
- `VotesController` (app/controllers/votes_controller.rb:3) - Coupled to ContentItem
- `CommentsController` (app/controllers/comments_controller.rb:3) - Coupled to ContentItem
- `ContentItemPolicy` (app/policies/content_item_policy.rb:3) - Pattern to follow for NotePolicy

**Architecture Decision:**
- Create separate NoteVotesController and NoteCommentsController (approach B)
- Rationale: Minimizes risk to existing ContentItem voting/commenting functionality
- Alternative considered: Make VotesController/CommentsController polymorphic (approach A) - rejected as more complex and risky

**Risk Assessment:**
- HIGH: Polymorphic migrations for Vote and Comment tables
- MEDIUM: Counter cache handling with polymorphic associations
- LOW: Link preview extraction (graceful failure acceptable)

**Plan Statistics:**
- Steps: 27
- Phases: 12
- Risks identified: 5
- Test coverage: Extensive (model, request, policy, service, job, feature specs)

---

### 2026-02-01 17:00 - Triage Complete

Quality gates:
- Lint: `bundle exec rubocop` + `bundle exec erb_lint --lint-all`
- Types: N/A (Ruby, no static typing)
- Tests: `bundle exec rspec --exclude-pattern 'spec/{performance,system/accessibility,i18n}/**/*_spec.rb'`
- Build: `bin/quality` (comprehensive: rubocop, erb_lint, brakeman, bundle-audit, rspec, i18n-tasks, schema validation, tenant isolation)

Task validation:
- Context: clear - problem well-defined (short-form social notes), codebase patterns documented
- Criteria: specific - 28 acceptance criteria with testable checkboxes
- Dependencies: none - MetaInspector gem present, Active Storage configured, SiteScoped concern exists

Complexity:
- Files: many - new model, controllers, views, services, policies, migrations; modifications to Vote, Comment, NetworkFeedService, DigestMailer
- Risk: medium/high - polymorphic migrations to Vote/Comment could affect existing data

Ready: yes

---

### 2026-02-01 - Task Expanded

- Intent: BUILD
- Scope: Full Notes feature including model, engagement, feeds, reposts, digest integration
- Key files to create:
  - `app/models/note.rb`
  - `app/controllers/notes_controller.rb`
  - `app/services/link_preview_service.rb`
  - `app/policies/note_policy.rb`
- Key files to modify:
  - `app/models/vote.rb` (polymorphic)
  - `app/models/comment.rb` (polymorphic)
  - `app/services/network_feed_service.rb`
  - `app/mailers/digest_mailer.rb`
- Complexity: HIGH
- Estimated effort: 0.83 person-weeks (per RICE score)

---

## Testing Evidence

_No tests run yet._

---

## Notes

**In Scope:**
- Note model with body, images, link previews
- CRUD operations and feeds
- Voting, commenting, bookmarking
- Reposts with attribution
- Network-wide notes aggregation
- Digest email integration
- Moderation (hide/flag)

**Out of Scope:**
- Rich text editing (body is plain text with auto-linked URLs)
- Multiple images per note (single image only)
- Note threading/replies (use comments for discussions)
- Push notifications for note activity
- Note scheduling (publish immediately or save as draft)
- Note analytics/metrics dashboard
- Hashtag system (use existing topic_tags if needed later)

**Assumptions:**
- 500 character limit is sufficient (Substack Notes allows ~8000)
- Editors and above can create notes (not all subscribers)
- Notes are public by default (no private notes)
- Link preview extraction can fail gracefully (note still saves)
- Reposts count toward the original note's engagement

**Edge Cases:**
1. **Empty body with image only**: Allow? Decision: Require body text (min 1 char)
2. **URL-only notes**: Auto-extract link preview, display as link card
3. **Repost of a repost**: Point to original note, not intermediate repost
4. **Deleted original note**: Repost remains but shows "original deleted"
5. **Hidden original note**: Reposts of hidden notes should also be hidden
6. **Cross-site reposts**: User must have editor role on target site
7. **Rate limiting**: 10 notes/hour, 100 votes/hour (consistent with existing)
8. **Link preview timeout**: MetaInspector has 20s timeout, job retries
9. **Large images**: Active Storage handles variants, validate max size (5MB)
10. **Network feed pagination**: Use offset/limit with proper caching

**Risks:**

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Polymorphic Vote/Comment migration breaks existing data | Medium | High | Careful migration with reversible changes, test on staging |
| Link preview extraction is slow/unreliable | Medium | Low | Background job, graceful failure, caching |
| Network notes feed performance | Medium | Medium | Heavy caching (5-15 min), proper indices |
| Scope creep (rich text, hashtags, etc.) | High | Medium | Strict out-of-scope list, create follow-up tasks |
| Moderation overhead | Low | Medium | Leverage existing Flag model, auto-hide on threshold |

**Dependencies:**
- MetaInspector gem (already installed)
- Active Storage (already configured)
- SiteScoped concern (exists)
- Polymorphic associations (Rails standard)

---

## Links

- Research: Substack Notes growth impact
- Related: `ContentItem` (app/models/content_item.rb:60), `Vote` (app/models/vote.rb:28), `NetworkFeedService` (app/services/network_feed_service.rb:5)
- Pattern reference: `Comment` model (app/models/comment.rb:33) for threading
- Digest reference: `DigestMailer` (app/mailers/digest_mailer.rb:3)
