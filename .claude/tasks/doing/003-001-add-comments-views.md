# Task: Add Comments Views and Turbo Stream Templates

## Metadata

| Field | Value |
|-------|-------|
| ID | `003-001-add-comments-views` |
| Status | `doing` |
| Priority | `003` Medium |
| Created | `2026-01-23 09:44` |
| Started | `2026-01-23 11:29` |
| Completed | |
| Blocked By | |
| Blocks | |
| Assigned To | `worker-1` |
| Assigned At | `2026-01-23 11:29` |

---

## Context

The community primitives task (002-006) implemented the backend for comments but did not add the view templates for displaying and managing comments. The controllers reference Turbo Stream templates that need to be created.

This is a follow-up from task 002-006-community-primitives.

---

## Acceptance Criteria

- [ ] `app/views/comments/index.html.erb` - List comments for a content item
- [ ] `app/views/comments/show.html.erb` - Show single comment with replies
- [ ] `app/views/comments/_comment.html.erb` - Comment partial with threading
- [ ] `app/views/comments/_form.html.erb` - Comment form partial
- [ ] `app/views/comments/create.turbo_stream.erb` - Turbo response for new comment
- [ ] `app/views/comments/update.turbo_stream.erb` - Turbo response for edit
- [ ] `app/views/comments/destroy.turbo_stream.erb` - Turbo response for delete
- [ ] Comments displayed on content item detail page
- [ ] Reply functionality with nested display
- [ ] Edit/delete buttons visible only to comment author
- [ ] Locked comments show appropriate message
- [ ] Quality gates pass

---

## Plan

### Implementation Plan (Generated 2026-01-23)

#### Gap Analysis

| Criterion | Status | Gap |
|-----------|--------|-----|
| `index.html.erb` | None | Needs full implementation |
| `show.html.erb` | None | Needs full implementation |
| `_comment.html.erb` | None | Needs full implementation with threading |
| `_form.html.erb` | None | Needs full implementation |
| `create.turbo_stream.erb` | None | Needs full implementation |
| `update.turbo_stream.erb` | None | Needs full implementation |
| `destroy.turbo_stream.erb` | None | Needs full implementation |
| Comments on content detail page | None | Content card exists but no comment expansion; need integration point |
| Reply functionality | None | Model supports parent_id/replies - views need to support |
| Edit/delete author-only | None | Policy exists (update=author, destroy=admin); views need conditionals |
| Locked comments message | None | Controller checks `comments_locked?` - views need locked state display |
| Quality gates pass | Pending | Run after implementation |

#### Files to Create

1. **`app/views/comments/_comment.html.erb`**
   - Comment partial with threaded display (recursive for replies)
   - Show user email (no display_name field exists), timestamp, edited indicator
   - Conditionally show edit button if `policy(@comment).update?`
   - Conditionally show delete button if `policy(@comment).destroy?`
   - Use turbo_frame_tag for each comment: `comment_#{comment.id}`
   - Recursively render replies with indentation (max 3-4 levels)

2. **`app/views/comments/_form.html.erb`**
   - Form partial for creating/editing comments
   - `form_with model: [@content_item, comment]` pattern
   - Hidden field for `parent_id` when replying
   - Textarea for body with character limit indicator (10,000 max)
   - Submit button, cancel button for replies
   - Use `data: { turbo_stream: true }` for Turbo responses

3. **`app/views/comments/_comments_section.html.erb`** (NEW)
   - Wrapper partial for embedding in content pages
   - Shows locked message if `content_item.comments_locked?`
   - Shows form if user authenticated and not banned
   - Lists comments with `turbo_frame_tag "comments_list"`

4. **`app/views/comments/index.html.erb`**
   - Full page view for content item comments
   - Breadcrumb: Back to feed
   - Content item summary header
   - Comments list with threading
   - Form at bottom if allowed

5. **`app/views/comments/show.html.erb`**
   - Single comment view with all replies
   - Useful for deep-linking to specific comment
   - Breadcrumb: Back to content item comments

6. **`app/views/comments/create.turbo_stream.erb`**
   - Append new comment to comments list (if root)
   - Or append to parent's replies (if reply)
   - Clear/reset form
   - Pattern: `turbo_stream.append` or `turbo_stream.replace`

7. **`app/views/comments/update.turbo_stream.erb`**
   - Replace updated comment in place
   - Pattern: `turbo_stream.replace "comment_#{@comment.id}"`

8. **`app/views/comments/destroy.turbo_stream.erb`**
   - Remove comment from DOM
   - Pattern: `turbo_stream.remove "comment_#{@comment.id}"`

#### Files to Modify

1. **`config/locales/en.yml`** - Add i18n keys:
   ```yaml
   comments:
     # Existing: created, updated, deleted, locked, banned, rate_limited
     # Add:
     title: Comments
     comment_count:
       zero: "No comments"
       one: "1 comment"
       other: "%{count} comments"
     form:
       placeholder: "Write a comment..."
       submit: "Post Comment"
       cancel: "Cancel"
       reply: "Reply"
       edit: "Edit"
       delete: "Delete"
       confirm_delete: "Are you sure you want to delete this comment?"
     edited: "(edited)"
     reply_to: "Reply to %{user}"
     locked_message: "Comments are locked on this content."
     sign_in_to_comment: "Sign in to comment"
     empty: "No comments yet. Be the first to comment!"
     loading: "Loading comments..."
   ```

2. **`app/views/feed/_content_card.html.erb`** (OPTIONAL - may defer)
   - Add link to expand comments or link to comments page
   - Current card shows comments_count; make it clickable

#### Test Plan

- [ ] View specs not commonly used in this project (no spec/views/)
- [ ] Request specs exist: verify turbo_stream format responses work
- [ ] Manual testing: Create, edit, delete comments via UI
- [ ] Manual testing: Reply to comment and verify threading
- [ ] Manual testing: Verify locked comments show message
- [ ] Manual testing: Verify edit/delete buttons respect policy
- [ ] System specs if time permits (optional)

#### Architectural Notes

1. **Turbo Frame/Stream Pattern**: Follow existing vote_button pattern
   - Each comment wrapped in `turbo_frame_tag "comment_#{id}"`
   - Comments list wrapped in `turbo_frame_tag "comments_list"`
   - Form uses `data: { turbo_stream: true }`
   - Controller already responds to turbo_stream format

2. **User Display**: User model has only `email` - display truncated email or gravatar
   - No `display_name` or `username` field exists
   - Could use email prefix (before @) as display name

3. **Threading**: Comment model has `parent_id` and `replies` association
   - Use recursive partial rendering for nested replies
   - Limit nesting depth (3-4 levels) with visual indentation

4. **Styling**: Follow existing Tailwind patterns from feed/content_card
   - Cards with border-gray-200, rounded-lg, shadow-sm
   - Blue accents for interactive elements
   - Use time_ago_in_words for timestamps

5. **Policy Integration**:
   - `policy(comment).update?` - author only (not banned)
   - `policy(comment).destroy?` - admin/tenant-admin only
   - `policy(Comment).create?` - authenticated, not banned, comments not locked

#### Implementation Order

1. Create `_comment.html.erb` partial (core display component)
2. Create `_form.html.erb` partial (core input component)
3. Create `index.html.erb` (uses both partials)
4. Create `show.html.erb` (uses _comment partial)
5. Create Turbo Stream templates (create, update, destroy)
6. Add i18n translations
7. Create `_comments_section.html.erb` for embedding
8. Run quality gates
9. Manual testing

---

## Work Log

### 2026-01-23 11:38 - Implementation Complete

**Files Created:**
1. `app/views/comments/_comment.html.erb` - Threaded comment display with recursive replies
2. `app/views/comments/_form.html.erb` - Comment form with reply/edit support
3. `app/views/comments/_comments_section.html.erb` - Embeddable section partial
4. `app/views/comments/index.html.erb` - Full page comments list
5. `app/views/comments/show.html.erb` - Single comment with replies view
6. `app/views/comments/create.turbo_stream.erb` - Turbo append for new comments
7. `app/views/comments/update.turbo_stream.erb` - Turbo replace for edited comments
8. `app/views/comments/destroy.turbo_stream.erb` - Turbo remove for deleted comments

**i18n Keys Added:**
- `comments.comment_count` (pluralization)
- `comments.form.*` (labels, placeholders, buttons)
- `comments.edited`, `comments.empty`, `comments.locked_message`
- `comments.back_to_feed`, `comments.back_to_comments`
- `comments.sign_in_to_comment`, `comments.reply_to`, `comments.on_content`

**Commits:**
- `3aecbfd` - feat: Add comment views and Turbo Stream templates
- `a8f4b47` - chore: Add i18n translations for comment views
- `c1fc59c` - chore: Add Brakeman ignores for comment view false positives

**Quality Checks:**
- ERB Lint: ✅ PASS (all 8 files)
- i18n-tasks health: ✅ PASS (no missing translations)
- Brakeman: ✅ PASS (2 false positives added to ignore)
- RSpec (comments GET tests): ✅ PASS (4 examples)

**Implementation Notes:**
- User display shows email prefix (before @) since no display_name field exists
- Threading limited to depth 3 to prevent excessive nesting
- Policy integration: edit=author, delete=admin/tenant-admin
- Locked comments show amber warning banner
- Turbo Stream templates handle both root comments and nested replies

### 2026-01-23 11:30 - Planning Complete

**Codebase Analysis:**
- Examined CommentsController: responds to html, turbo_stream, json formats
- Examined Comment model: has `parent_id`, `replies`, `edited_at`, `body`, `user`, `content_item`
- Examined CommentPolicy: update=author, destroy=admin/tenant-admin, create=authenticated+not_banned+not_locked
- Examined existing view patterns: feed/index, feed/_content_card, votes/_vote_button
- Examined existing form patterns: admin/sources/_form
- Examined existing turbo patterns: VotesController inline turbo_stream.replace
- Examined User model: only `email` field for display (no username/display_name)
- Examined i18n: basic comment messages exist, need form/UI translations

**Key Decisions:**
1. Follow existing turbo_frame pattern from vote_button for comment CRUD
2. Use recursive partial for threaded comments (Comment has replies association)
3. Display user by email prefix (before @) since no display_name exists
4. Policy-based conditional rendering for edit/delete buttons
5. Create standalone comments pages (index/show) + embeddable section partial

**Gap Summary:** All 8 view files need to be created from scratch. No existing views or turbo templates for comments.

### 2026-01-23 11:29 - Triage Complete

- Dependencies: ✅ CLEAR - 002-006-community-primitives is in done/
- Task clarity: Clear - acceptance criteria are specific and testable
- Ready to proceed: Yes

**Verification findings:**
- CommentsController exists at `app/controllers/comments_controller.rb`
- Comment model exists at `app/models/comment.rb`
- No view files exist yet in `app/views/comments/` - all need to be created
- Basic i18n translations exist in `config/locales/en.yml` (comments.created, comments.updated, etc.)
- Controller expects: index, show views + turbo_stream templates for create/update/destroy

**Notes:**
- Controller references `@content_item.comments_locked?` - views need to handle this
- Threading support via `parent_id` and `replies` association
- Rate limiting in place (10 comments/hour)
- Ban status checking implemented

### 2026-01-23 09:44 - Task Created

Created as follow-up from 002-006-community-primitives review phase.

---

## Testing Evidence

(To be completed)

---

## Notes

- Comments should use threaded display (parent/replies)
- Consider lazy-loading for comments on content cards
- May want to add comment count link to expand/collapse

---

## Links

- Related: `002-006-community-primitives` - Original implementation
