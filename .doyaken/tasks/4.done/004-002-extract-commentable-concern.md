# Task: Extract Commentable Controller Concern

## Metadata

| Field       | Value                                  |
| ----------- | -------------------------------------- |
| ID          | `004-002-extract-commentable-concern`  |
| Status      | `done`                                 |
| Completed   | `2026-02-02 02:37`                     |
| Started     | `2026-02-02 02:23`                     |
| Assigned To | `worker-1`                             |
| Priority    | `002` High                             |
| Created     | `2026-02-01 19:20`                     |
| Labels      | `technical-debt`, `refactor`           |

---

## Context

**Intent**: IMPROVE

Code duplication exists across three controllers handling user-generated content responses:
- `CommentsController` (for ContentItem comments)
- `NoteCommentsController` (for Note comments)
- `DiscussionPostsController` (for Discussion posts)

Flay analysis identified mass=116 (2x) and mass=112 duplications. The duplicated patterns are:

1. **Create action** (~15 lines each):
   - Build record from parent association
   - Assign user and site
   - Authorize
   - Rate limit check
   - Save with respond_to block
   - Track action on success

2. **Update action** (~12 lines each):
   - Authorize
   - Update with params
   - Mark as edited
   - respond_to block

3. **Destroy action** (~8 lines each):
   - Authorize
   - Destroy
   - respond_to block

**Key Differences to Account For:**
- Different parent models (`@content_item`, `@note`, `@discussion`)
- `CommentsController` and `NoteCommentsController` use `Comment` model; `DiscussionPostsController` uses `DiscussionPost` model
- Different param keys (`comment` vs `discussion_post`)
- Different rate limit actions (`:comment` vs `:discussion_post`)
- Different I18n namespaces
- Different fallback locations for redirects
- `CommentsController` has `index` and `show` actions (not shared)
- Different delete policies (comments: admin-only, discussion_posts: author or admin)
- Different locking mechanisms (`comments_locked?` vs `locked?`)

---

## Acceptance Criteria

- [x] Create `Commentable` concern at `app/controllers/concerns/commentable.rb`
- [x] Concern provides `create`, `update`, and `destroy` actions with template method pattern
- [x] Concern requires subclasses to implement: `commentable_build_record`, `commentable_record`, `commentable_params`, `rate_limit_action`, `i18n_namespace`, `commentable_fallback_location`
- [x] Refactor `CommentsController` to include concern and implement hooks
- [x] Refactor `NoteCommentsController` to include concern and implement hooks
- [x] Refactor `DiscussionPostsController` to include concern and implement hooks
- [x] Controllers retain their unique `index`, `show`, and locking behavior where applicable
- [x] All 93 existing request specs continue to pass unchanged
- [x] Quality gates pass (RuboCop, Brakeman, etc.)

---

## Plan

### Gap Analysis

| Criterion | Status | Gap |
|-----------|--------|-----|
| Create `Commentable` concern | none | Need to create new file |
| Concern provides `create`, `update`, `destroy` actions | none | Must extract from 3 controllers |
| Concern requires template methods | none | Must define 6 hooks with `NotImplementedError` |
| Refactor `CommentsController` | none | Must include concern and implement hooks |
| Refactor `NoteCommentsController` | none | Must include concern and implement hooks |
| Refactor `DiscussionPostsController` | none | Must include concern and implement hooks |
| Controllers retain unique behavior | full | `index`, `show`, locking already in controllers |
| All 63 request specs pass | full | Tests exist, need verification after changes |
| Quality gates pass | full | Will verify after implementation |

### Risks

- [ ] **Subtle response differences**: The `DiscussionPostsController` uses `redirect_to @discussion` while comment controllers use `redirect_back`. Mitigation: Ensure `commentable_fallback_location` is flexible enough to handle both patterns
- [ ] **Instance variable naming**: Concern actions set `@commentable_record` but existing views/turbo streams expect `@comment` or `@post`. Mitigation: Keep instance variable assignment in controller hooks, not concern
- [ ] **HTML format differences**: Comments use `redirect_back`, discussions use `redirect_to`. Mitigation: Use `commentable_redirect_method` hook or always use `redirect_to` with `commentable_fallback_location` which subclasses can set to parent

### Steps

1. **Create Commentable concern skeleton**
   - File: `app/controllers/concerns/commentable.rb`
   - Change: Create module with `ActiveSupport::Concern`, `included` block, 6 template methods raising `NotImplementedError`
   - Verify: File exists, RuboCop passes

2. **Implement create action in concern**
   - File: `app/controllers/concerns/commentable.rb`
   - Change: Add `create` action that:
     - Calls `commentable_build_record` to build from parent (returns new record)
     - Sets `user = current_user`, `site = Current.site`
     - Calls `authorize @record`
     - Checks rate limit with `rate_limited?(current_user, rate_limit_action, **RateLimitable::LIMITS[rate_limit_action])`
     - Saves with respond_to block
     - Calls `track_action(current_user, rate_limit_action)` on success
   - Verify: Concern compiles without errors

3. **Implement update action in concern**
   - File: `app/controllers/concerns/commentable.rb`
   - Change: Add `update` action that:
     - Calls `authorize commentable_record`
     - Updates with `commentable_params`
     - Calls `mark_as_edited!` on success
     - respond_to block with success/error handling
   - Verify: Concern compiles

4. **Implement destroy action in concern**
   - File: `app/controllers/concerns/commentable.rb`
   - Change: Add `destroy` action that:
     - Calls `authorize commentable_record`
     - Destroys record
     - respond_to block
   - Verify: Concern compiles

5. **Refactor CommentsController to use concern**
   - File: `app/controllers/comments_controller.rb`
   - Change:
     - Add `include Commentable`
     - Remove `create`, `update`, `destroy` action methods
     - Keep: `index`, `show`, `set_content_item`, `set_comment`, `check_comments_locked`, `comment_params`
     - Implement hooks:
       - `commentable_build_record` → `@comment = @content_item.comments.build(comment_params)`
       - `commentable_record` → `@comment`
       - `commentable_params` → `comment_params`
       - `rate_limit_action` → `:comment`
       - `i18n_namespace` → `"comments"`
       - `commentable_fallback_location` → `feed_index_path`
   - Verify: `bin/rspec spec/requests/comments_spec.rb` passes (26 examples)

6. **Refactor NoteCommentsController to use concern**
   - File: `app/controllers/note_comments_controller.rb`
   - Change:
     - Add `include Commentable`
     - Remove `create`, `update`, `destroy` action methods
     - Keep: `index`, `set_note`, `set_comment`, `comment_params`
     - Implement hooks:
       - `commentable_build_record` → `@comment = @note.comments.build(comment_params)`
       - `commentable_record` → `@comment`
       - `commentable_params` → `comment_params`
       - `rate_limit_action` → `:comment`
       - `i18n_namespace` → `"comments"`
       - `commentable_fallback_location` → `@note`
   - Verify: `bin/rspec spec/requests/note_comments_spec.rb` passes (26 examples)

7. **Refactor DiscussionPostsController to use concern**
   - File: `app/controllers/discussion_posts_controller.rb`
   - Change:
     - Add `include Commentable`
     - Remove `create`, `update`, `destroy` action methods
     - Keep: `set_discussion`, `set_post`, `check_discussion_locked`, `post_params`
     - Implement hooks:
       - `commentable_build_record` → `@post = @discussion.posts.build(post_params)`
       - `commentable_record` → `@post`
       - `commentable_params` → `post_params`
       - `rate_limit_action` → `:discussion_post`
       - `i18n_namespace` → `"discussion_posts"`
       - `commentable_fallback_location` → `@discussion`
   - Verify: `bin/rspec spec/requests/discussion_posts_spec.rb` passes (24 examples)

8. **Run full test suite and quality gates**
   - Command: `bin/rspec spec/requests/comments_spec.rb spec/requests/note_comments_spec.rb spec/requests/discussion_posts_spec.rb`
   - Command: `bin/rubocop app/controllers/concerns/commentable.rb app/controllers/comments_controller.rb app/controllers/note_comments_controller.rb app/controllers/discussion_posts_controller.rb`
   - Verify: All 76 request specs pass, no RuboCop offenses

### Checkpoints

| After Step | Verify |
|------------|--------|
| Step 4 | Concern file compiles: `ruby -c app/controllers/concerns/commentable.rb` |
| Step 5 | CommentsController specs pass: 26 examples |
| Step 6 | NoteCommentsController specs pass: 26 examples |
| Step 7 | DiscussionPostsController specs pass: 24 examples |
| Step 8 | Full quality check passes |

### Test Plan

- [ ] Unit: Not needed (concern tested indirectly through request specs)
- [ ] Integration: 76 existing request specs provide full coverage:
  - `spec/requests/comments_spec.rb` (26 examples)
  - `spec/requests/note_comments_spec.rb` (26 examples)
  - `spec/requests/discussion_posts_spec.rb` (24 examples)

### Docs to Update

- [ ] None required (internal refactoring, no API changes)

---

## Notes

**In Scope:**
- Extract shared create/update/destroy logic into concern
- Refactor all three controllers to use concern
- Maintain 100% test pass rate

**Out of Scope:**
- Unifying Comment and DiscussionPost models (different domains)
- Adding shared concern tests (existing request specs provide coverage)
- Changing any controller behavior or API responses
- Modifying views or turbo stream templates

**Assumptions:**
- The `Votable` concern pattern is the preferred style for this codebase
- Request specs provide sufficient coverage (no unit tests for concerns needed)
- Rate limiting and ban checking remain in individual controllers via before_action

**Edge Cases:**
- CommentsController has `show` action that others don't - keep in controller
- DiscussionPostsController allows author deletion, CommentsController doesn't - authorization is in Pundit policies, not controller
- Different locking mechanisms - keep `check_*_locked` in individual controllers

**Risks:**
- **Low**: Subtle behavior differences could cause test failures → Mitigation: Run tests after each refactor step
- **Low**: Missing a template method could cause runtime errors → Mitigation: Use `NotImplementedError` pattern from `Votable`

---

## Links

- Related: `app/controllers/comments_controller.rb`
- Related: `app/controllers/note_comments_controller.rb`
- Related: `app/controllers/discussion_posts_controller.rb`
- Pattern: `app/controllers/concerns/votable.rb`

---

## Work Log

### 2026-02-02 02:51 - Verification Complete

Criteria: all met

| Criterion | Status | Evidence |
|-----------|--------|----------|
| Create `Commentable` concern | [x] | `app/controllers/concerns/commentable.rb` exists (152 lines) |
| Concern provides `create`, `update`, `destroy` actions | [x] | Lines 45-103 implement all three actions |
| Concern requires 6 template methods | [x] | Lines 124-150 define all 6 with `NotImplementedError` |
| Refactor `CommentsController` | [x] | `include Commentable` at line 4, hooks at lines 54-76 |
| Refactor `NoteCommentsController` | [x] | `include Commentable` at line 4, hooks at lines 38-60 |
| Refactor `DiscussionPostsController` | [x] | `include Commentable` at line 4, hooks at lines 38-64 |
| Controllers retain unique behavior | [x] | `index`/`show` kept in CommentsController, locking in respective controllers |
| All 93 request specs pass | [x] | `bundle exec rspec` - 93 examples, 0 failures |
| Quality gates pass | [x] | RuboCop: 4 files, no offenses; Brakeman: 0 warnings |

Quality gates: all pass
- Lint: pass (RuboCop: 4 files inspected, no offenses)
- Tests: pass (93 examples, 0 failures)
- Security: pass (Brakeman: 0 warnings)

CI: pass - https://github.com/mitchellfyi/curated.cx/actions/runs/21575481857
- Code Style ✓
- Tests ✓
- Security ✓
- Build ✓
- Quality Analysis ✓
- CI Complete ✓
- Deploy to Production ✓

Task location: 3.doing → 4.done
Reason: complete - all acceptance criteria met, all quality gates pass, CI green

---

### 2026-02-02 02:37 - Review Complete

Findings:
- Blockers: 0
- High: 0
- Medium: 0
- Low: 0

Review passes:
- Correctness: pass - All behavior exactly preserved, verified against original code
- Design: pass - Follows existing `Votable` concern pattern exactly
- Security: pass - Proper authorization, authentication, rate limiting, strong params
- Performance: pass - No N+1 queries, single-record operations
- Tests: pass - 93 request specs cover all paths

All criteria met: yes
Follow-up tasks: none

Status: COMPLETE

---

### 2026-02-02 02:35 - Documentation Sync

Docs updated:
- None required (internal refactoring, no API changes)

Inline comments:
- `app/controllers/concerns/commentable.rb:3-37` - Module documentation with usage example
- `app/controllers/concerns/commentable.rb:107-150` - Method-level comments for all private methods
- `app/controllers/comments_controller.rb:52` - Section comment for Commentable hooks

Consistency: verified
- Concern documentation matches actual implementation
- Example usage in concern header matches real controller implementations
- All template methods documented with purpose and expected return types
- No external docs (README, ARCHITECTURE.md) reference these controllers' internals

---

### 2026-02-02 02:32 - Testing Complete

Tests written:
- No new tests needed (existing 93 request specs provide full coverage)

Quality gates:
- Lint: pass (RuboCop: 4 files inspected, no offenses)
- Types: N/A (Ruby/Rails project)
- Tests: pass (3851 total, 93 for Commentable controllers)
- Build: N/A (Rails - no build step)
- Security: pass (Brakeman: 0 warnings)

CI ready: yes
- All tests run on standard RSpec
- No platform-specific code (runs on ubuntu-latest in CI)
- No hardcoded paths or macOS-specific commands
- No flaky tests (deterministic, no timing dependencies)

---

### 2026-02-02 02:28 - Implementation Complete

Steps completed:
1. Created `app/controllers/concerns/commentable.rb` with create/update/destroy actions
2. Refactored `CommentsController` - 31 specs pass
3. Refactored `NoteCommentsController` - 33 specs pass
4. Refactored `DiscussionPostsController` - 29 specs pass

Files modified:
- Created: `app/controllers/concerns/commentable.rb` (133 lines)
- Modified: `app/controllers/comments_controller.rb` (110→77 lines, -33 lines)
- Modified: `app/controllers/note_comments_controller.rb` (94→61 lines, -33 lines)
- Modified: `app/controllers/discussion_posts_controller.rb` (94→65 lines, -29 lines)

Verification:
- All 93 request specs pass (31+33+29)
- RuboCop: 4 files inspected, no offenses
- Brakeman: no security warnings
- Full quality suite passes

Implementation notes:
- Added `commentable_redirect_back?` hook to handle `redirect_back` vs `redirect_to` difference
- `DiscussionPostsController` overrides to return `false` (uses `redirect_to`)
- Instance variables (`@comment`, `@post`) set in controller hooks for view compatibility
- Template methods follow `Votable` pattern with `NotImplementedError`

---

### 2026-02-02 02:24 - Planning Complete

- Steps: 8
- Risks: 3 (all low severity)
- Test coverage: extensive (76 existing request specs)

Analysis notes:
- Reviewed all 3 controllers in detail - create/update/destroy actions are nearly identical
- Key variance: `CommentsController` uses `redirect_back` while `DiscussionPostsController` uses `redirect_to`
- Solution: Use `redirect_to commentable_fallback_location` consistently - controllers set appropriate fallback
- `NoteCommentsController` has no locking check (notes don't have lock feature)
- Instance variables (`@comment`, `@post`) must be set in controller hooks to maintain view compatibility
- Turbo stream templates don't need changes since they reference controller-specific instance variables

---

### 2026-02-02 02:23 - Triage Complete

Quality gates:
- Lint: `bin/rubocop` (RuboCop Rails Omakase)
- Types: N/A (Ruby/Rails project)
- Tests: `bin/rspec`
- Build: N/A (Rails - no build step)
- Full quality: `bin/quality` (comprehensive quality enforcement script)

Task validation:
- Context: clear (Flay analysis identified mass=116/112 duplications, 3 controllers with shared patterns)
- Criteria: specific (9 acceptance criteria, all testable)
- Dependencies: none (no blockers, `Votable` pattern exists as reference)

Complexity:
- Files: few (1 new concern, 3 controller modifications)
- Risk: low (refactoring with 63 existing request specs for regression safety)

Verified files exist:
- `app/controllers/comments_controller.rb` ✓
- `app/controllers/note_comments_controller.rb` ✓
- `app/controllers/discussion_posts_controller.rb` ✓
- `app/controllers/concerns/votable.rb` ✓ (pattern reference)
- `spec/requests/comments_spec.rb` ✓
- `spec/requests/note_comments_spec.rb` ✓
- `spec/requests/discussion_posts_spec.rb` ✓

Ready: yes

---

### 2026-02-02 02:22 - Task Expanded

- Intent: IMPROVE (refactoring to reduce duplication)
- Scope: Extract shared create/update/destroy logic from 3 controllers into `Commentable` concern
- Key files:
  - Create: `app/controllers/concerns/commentable.rb`
  - Modify: `app/controllers/comments_controller.rb`
  - Modify: `app/controllers/note_comments_controller.rb`
  - Modify: `app/controllers/discussion_posts_controller.rb`
- Complexity: Medium (template method pattern with 6 hooks, 3 controllers, 63 existing tests)
- Analysis: Reviewed all 3 controllers, existing `Votable` concern for pattern guidance, and all request specs for test coverage
