# Task: Extract Votable Controller Concern

## Metadata

| Field       | Value                              |
| ----------- | ---------------------------------- |
| ID          | `004-001-extract-votable-concern`  |
| Status      | `done`                             |
| Completed   | `2026-02-01 19:37`                 |
| Priority    | `002` High                         |
| Created     | `2026-02-01 19:20`                 |
| Started     | `2026-02-01 19:25`                 |
| Assigned To | `worker-1`                         |
| Labels      | `technical-debt`, `refactor`       |

---

## Context

**Intent**: IMPROVE (refactor)

Code duplication exists between `VotesController` and `NoteVotesController`. Both controllers implement identical toggle logic (lines 12-35) that:
1. Checks rate limiting
2. Finds or creates/destroys a vote
3. Tracks the action
4. Responds in multiple formats (HTML, turbo_stream, JSON)

The only differences are:
- **Votable model**: `@content_item` vs `@note`
- **Set method**: `set_content_item` vs `set_note`
- **Turbo stream DOM ID**: `vote-button-#{id}` vs `note-vote-button-#{id}`
- **Partial path**: `votes/vote_button` vs `note_votes/vote_button`
- **Fallback location**: `feed_index_path` vs `notes_path`

The Vote model already uses a polymorphic `votable` association (`votable_type`, `votable_id`), making this a natural fit for a concern-based abstraction.

Flay analysis identified this as mass=168 duplication.

---

## Acceptance Criteria

- [x] Create `Votable` concern at `app/controllers/concerns/votable.rb`
  - Concern includes `RateLimitable` and `BanCheckable`
  - Provides shared `toggle` action using `@votable` instance variable
  - Requires implementing controllers to define `votable_resource` method
  - Requires implementing controllers to define `votable_dom_id` method
  - Requires implementing controllers to define `votable_partial` method
  - Requires implementing controllers to define `fallback_location` method
- [x] Refactor `VotesController` to use concern
  - Include `Votable` concern
  - Implement `set_votable` to set `@votable = ContentItem.find(params[:id])`
  - Implement hook methods for DOM ID, partial, and fallback
  - Remove duplicated toggle logic
- [x] Refactor `NoteVotesController` to use concern
  - Include `Votable` concern
  - Implement `set_votable` to set `@votable = Note.find(params[:id])`
  - Implement hook methods for DOM ID, partial, and fallback
  - Remove duplicated toggle logic
- [x] All existing tests pass unchanged (`spec/requests/votes_spec.rb`, `spec/requests/note_votes_spec.rb`)
- [x] Quality gates pass (rubocop, tests)
- [x] Changes committed with task reference

---

## Plan

### Gap Analysis

| Criterion | Status | Gap |
|-----------|--------|-----|
| Create Votable concern | none | Need to create from scratch |
| Concern includes RateLimitable | none | RateLimitable is a model concern; need to decide inclusion strategy |
| Concern provides toggle action | none | Extract from existing controllers |
| VotesController uses concern | none | Controller exists, needs refactoring |
| NoteVotesController uses concern | none | Controller exists, needs refactoring |
| All existing tests pass | full | Tests exist and are comprehensive |
| Quality gates pass | full | rubocop and rspec available |

### Risks

- [ ] **RateLimitable location**: It's in `app/models/concerns/` but used by controllers. Both existing controllers include it successfully. Mitigation: Include RateLimitable in new Votable concern, same pattern as existing controllers.
- [ ] **Partial local variable names differ**: `votes/_vote_button` expects `content_item:`, `note_votes/_vote_button` expects `note:`. Mitigation: Add `votable_partial_locals` hook method.
- [ ] **turbo_stream.erb template exists for notes**: `note_votes/toggle.turbo_stream.erb` exists but `VotesController` renders inline. Mitigation: Keep inline rendering approach in concern for consistency; delete the redundant template file.

### Steps

1. **Create Votable concern skeleton**
   - File: `app/controllers/concerns/votable.rb`
   - Change: Create concern with `extend ActiveSupport::Concern`, include `RateLimitable` and `BanCheckable`
   - Verify: `bin/rubocop app/controllers/concerns/votable.rb` passes

2. **Add concern interface - required hooks**
   - File: `app/controllers/concerns/votable.rb`
   - Change: Add `included` block with `before_action :set_votable` callback. Define abstract hook methods with `raise NotImplementedError`:
     - `set_votable` - sets `@votable`
     - `votable_dom_id` - returns DOM ID string
     - `votable_partial` - returns partial path
     - `votable_partial_locals` - returns hash for partial locals
     - `votable_fallback_location` - returns fallback path
   - Verify: `bin/rubocop app/controllers/concerns/votable.rb` passes

3. **Add toggle action to concern**
   - File: `app/controllers/concerns/votable.rb`
   - Change: Add `toggle` method that:
     - Authorizes Vote policy
     - Checks rate limit (return `render_rate_limited` if exceeded)
     - Finds or creates/destroys vote on `@votable`
     - Tracks action on create
     - Responds in HTML (redirect), turbo_stream (replace), JSON (voted + count)
   - Verify: `bin/rubocop app/controllers/concerns/votable.rb` passes

4. **Refactor VotesController to use concern**
   - File: `app/controllers/votes_controller.rb`
   - Change:
     - Replace `include RateLimitable` and `include BanCheckable` with `include Votable`
     - Keep `before_action :authenticate_user!` and `before_action :check_ban_status`
     - Remove `before_action :set_content_item` (handled by concern)
     - Rename `set_content_item` to `set_votable`, set `@votable = ContentItem.find(params[:id])`
     - Add `votable_dom_id` returning `"vote-button-#{@votable.id}"`
     - Add `votable_partial` returning `"votes/vote_button"`
     - Add `votable_partial_locals` returning `{ content_item: @votable, voted: @voted }`
     - Add `votable_fallback_location` returning `feed_index_path`
     - Remove `toggle` action (now in concern)
     - Remove `render_vote_update` private method (now in concern)
   - Verify: `bundle exec rspec spec/requests/votes_spec.rb` passes

5. **Refactor NoteVotesController to use concern**
   - File: `app/controllers/note_votes_controller.rb`
   - Change:
     - Replace `include RateLimitable` and `include BanCheckable` with `include Votable`
     - Keep `before_action :authenticate_user!` and `before_action :check_ban_status`
     - Remove `before_action :set_note` (handled by concern)
     - Rename `set_note` to `set_votable`, set `@votable = Note.find(params[:id])`
     - Add `votable_dom_id` returning `"note-vote-button-#{@votable.id}"`
     - Add `votable_partial` returning `"note_votes/vote_button"`
     - Add `votable_partial_locals` returning `{ note: @votable, voted: @voted }`
     - Add `votable_fallback_location` returning `notes_path`
     - Remove `toggle` action (now in concern)
     - Remove `render_vote_update` private method (now in concern)
   - Verify: `bundle exec rspec spec/requests/note_votes_spec.rb` passes

6. **Delete redundant turbo_stream template**
   - File: `app/views/note_votes/toggle.turbo_stream.erb`
   - Change: Delete file (turbo_stream rendering now inline in concern)
   - Verify: `bundle exec rspec spec/requests/note_votes_spec.rb` passes

7. **Run full test suite and quality gates**
   - Verify: `bundle exec rspec` passes (all tests)
   - Verify: `bin/rubocop` passes (no offenses)

### Checkpoints

| After Step | Verify |
|------------|--------|
| Step 3 | Concern file complete, rubocop passes |
| Step 4 | VotesController tests pass |
| Step 5 | NoteVotesController tests pass |
| Step 7 | Full suite green, rubocop clean |

### Test Plan

- [ ] Unit: No new tests needed (existing request specs are comprehensive)
- [ ] Integration: Existing specs cover all formats (HTML, turbo_stream, JSON), rate limiting, ban checking, site isolation

### Docs to Update

- [ ] None required (internal refactor, no API changes)

---

## Notes

**In Scope:**
- Extract common voting toggle logic to concern
- Refactor both vote controllers to use concern
- Maintain all existing behavior and test coverage

**Out of Scope:**
- Refactoring view partials (they remain model-specific)
- Extracting similar comments controller duplication (future task)
- Adding new tests (existing tests are comprehensive)

**Assumptions:**
- View partials will continue to accept their respective model types
- Controllers will maintain their current before_action ordering

**Edge Cases:**
- Rate limiting: Handled by existing `RateLimitable` concern (included in new concern)
- Ban checking: Handled by existing `BanCheckable` concern (included in new concern)
- Turbo stream responses: Each controller provides its own DOM ID via hook method

**Risks:**
| Risk | Mitigation |
|------|------------|
| Existing tests break | Run full test suite after each step; existing tests are comprehensive |
| View partials break | Partials unchanged; they receive model via locals |
| Response format differences | Abstract via hook methods, not inheritance |

---

## Links

- Related: `app/controllers/votes_controller.rb`
- Related: `app/controllers/note_votes_controller.rb`
- Related: `app/models/vote.rb` (polymorphic votable association)
- Related: `app/controllers/concerns/ban_checkable.rb` (pattern reference)
- Future: Comments controller duplication (`comments_controller.rb`, `note_comments_controller.rb`)

---

## Work Log

### 2026-02-01 19:23 - Task Expanded

- Intent: IMPROVE (refactor to reduce duplication)
- Scope: Extract shared voting logic into Votable concern, refactor two controllers
- Key files to modify:
  - Create: `app/controllers/concerns/votable.rb`
  - Modify: `app/controllers/votes_controller.rb`
  - Modify: `app/controllers/note_votes_controller.rb`
- Complexity: Low-Medium (straightforward extraction, well-tested existing code)
- Test files: `spec/requests/votes_spec.rb`, `spec/requests/note_votes_spec.rb` (comprehensive, no changes needed)

### 2026-02-01 19:25 - Triage Complete

Quality gates:
- Lint: `bin/rubocop` (rubocop-rails-omakase)
- Types: N/A (Ruby, no static typing)
- Tests: `bundle exec rspec`
- Build: N/A (Rails, no build step)

Task validation:
- Context: clear (duplication identified between two controllers, lines 12-35)
- Criteria: specific (6 checkboxes with precise requirements)
- Dependencies: none (RateLimitable and BanCheckable concerns already exist)

Complexity:
- Files: few (create 1, modify 2)
- Risk: low (comprehensive existing tests, straightforward extraction pattern)

Verified files exist:
- `app/controllers/votes_controller.rb` ✓
- `app/controllers/note_votes_controller.rb` ✓
- `app/controllers/concerns/ban_checkable.rb` ✓ (pattern reference)
- `spec/requests/votes_spec.rb` ✓
- `spec/requests/note_votes_spec.rb` ✓

Note: Manifest quality commands are empty but standard Rails tooling confirmed:
- rubocop via `bin/rubocop`
- rspec via `bundle exec rspec`

Ready: yes

### 2026-02-01 19:26 - Planning Complete

- Steps: 7
- Risks: 3 (all mitigated)
- Test coverage: extensive (existing request specs cover all scenarios)

Key findings from codebase analysis:
- `RateLimitable` is in `app/models/concerns/` but controllers include it (this works)
- View partials expect different local names (`content_item:` vs `note:`) - handled via `votable_partial_locals` hook
- `note_votes/toggle.turbo_stream.erb` is redundant once concern renders inline
- Existing tests are comprehensive: JSON/HTML/turbo_stream formats, rate limiting, ban checking, site isolation

### 2026-02-01 19:27 - Implementation Progress

Step 1: Create Votable concern skeleton
- Files modified: `app/controllers/concerns/votable.rb` (created)
- Verification: rubocop pass

Step 2: Add concern interface - required hooks
- Files modified: `app/controllers/concerns/votable.rb`
- Verification: rubocop pass

Step 3: Add toggle action to concern
- Files modified: `app/controllers/concerns/votable.rb`
- Verification: rubocop pass

Step 4: Refactor VotesController to use concern
- Files modified: `app/controllers/votes_controller.rb`
- Verification: rspec spec/requests/votes_spec.rb (15 examples, 0 failures)

Step 5: Refactor NoteVotesController to use concern
- Files modified: `app/controllers/note_votes_controller.rb`
- Verification: rspec spec/requests/note_votes_spec.rb (17 examples, 0 failures)

Step 6: Delete redundant turbo_stream template
- Files deleted: `app/views/note_votes/toggle.turbo_stream.erb`
- Verification: rspec spec/requests/note_votes_spec.rb (17 examples, 0 failures)

Step 7: Run full test suite and quality gates
- Verification: rspec (3902 examples, 0 failures, 1 pending)
- Verification: rubocop (582 files inspected, no offenses detected)
- Commit: 6e729fa

### 2026-02-01 19:32 - Testing Complete

Tests written:
- No new tests required (existing request specs are comprehensive)

Existing test coverage:
- `spec/requests/votes_spec.rb` - 15 tests (integration)
- `spec/requests/note_votes_spec.rb` - 17 tests (integration)

Coverage of Votable concern functionality:
- toggle action: vote creation/destruction ✓
- rate limiting: within limit and exceeded ✓
- ban checking: forbidden for banned users ✓
- HTML format: redirect back ✓
- turbo_stream format: replaces vote button element ✓
- JSON format: returns voted status and count ✓
- site isolation: votes scoped to current site ✓

Quality gates:
- Lint: pass (582 files inspected, no offenses)
- Types: N/A (Ruby)
- Tests: pass (3902 total, 0 failures, 1 pending)
- Build: N/A (Rails)

CI ready: yes

### 2026-02-01 19:36 - Documentation Sync

Docs updated:
- None required (internal refactor, no user-facing API changes)

Inline comments:
- `app/controllers/concerns/votable.rb:1-31` - Comprehensive module documentation with usage example already in place

Consistency:
- Verified: `docs/moderation.md` references RateLimitable pattern (lines 403-411) - example still conceptually valid; Votable now includes RateLimitable internally
- Verified: `docs/ARCHITECTURE.md` - high-level architecture, doesn't document controller concerns
- Verified: New concern has complete inline documentation with example usage

No changes needed: task was internal refactor with no API surface changes

### 2026-02-01 19:37 - Review Complete

Findings:
- Blockers: 0
- High: 0
- Medium: 0
- Low: 0

Review passes:
- Correctness: pass - happy/edge paths traced, no silent failures
- Design: pass - clean concern pattern, consistent with codebase
- Security: pass - auth, authz (Pundit), rate limiting, site isolation all present
- Performance: pass - no N+1, no unbounded loops, cache-based rate limiting
- Tests: pass - 32 examples passing, comprehensive coverage

All criteria met: yes
Follow-up tasks: none

Status: COMPLETE
