# Task: Extract Commentable Controller Concern

## Metadata

| Field       | Value                                  |
| ----------- | -------------------------------------- |
| ID          | `004-002-extract-commentable-concern`  |
| Status      | `todo`                                 |
| Priority    | `002` High                             |
| Created     | `2026-02-01 19:20`                     |
| Labels      | `technical-debt`, `refactor`           |

---

## Context

Identical code duplication found in comment controllers:
- `CommentsController` lines 49 and 68
- `NoteCommentsController` lines 43 and 62
- `DiscussionPostsController` lines 33 and 52

Flay analysis identified these as mass=116 (2x) and mass=112 duplications.

---

## Acceptance Criteria

- [ ] Create `Commentable` concern for polymorphic commenting
- [ ] Refactor `CommentsController` to use concern
- [ ] Refactor `NoteCommentsController` to use concern
- [ ] Refactor `DiscussionPostsController` to use concern
- [ ] Tests pass
- [ ] Quality gates pass

---

## Plan

1. **Create concern**: `app/controllers/concerns/commentable.rb`
   - Extract common create/update logic
   - Use polymorphic association pattern

2. **Refactor controllers**
   - Include concern in all three controllers
   - Override `set_commentable` in each

3. **Update tests**
   - Ensure existing tests still pass

---

## Notes

- Consider unifying these models if appropriate
- Files: `app/controllers/comments_controller.rb:49`, `app/controllers/note_comments_controller.rb:43`

---

## Links

- Related: `app/controllers/comments_controller.rb`
- Related: `app/controllers/note_comments_controller.rb`
- Related: `app/controllers/discussion_posts_controller.rb`
