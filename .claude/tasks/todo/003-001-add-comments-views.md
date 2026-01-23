# Task: Add Comments Views and Turbo Stream Templates

## Metadata

| Field | Value |
|-------|-------|
| ID | `003-001-add-comments-views` |
| Status | `todo` |
| Priority | `003` Medium |
| Created | `2026-01-23 09:44` |
| Started | |
| Completed | |
| Blocked By | |
| Blocks | |
| Assigned To | |
| Assigned At | |

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

1. Create comment partials (_comment.html.erb, _form.html.erb)
2. Create index/show views
3. Create Turbo Stream templates for CRUD
4. Integrate comments section into content item views
5. Style with Tailwind CSS
6. Add appropriate i18n translations
7. Test views manually

---

## Work Log

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
