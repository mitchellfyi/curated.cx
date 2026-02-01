# Task: Extract Votable Controller Concern

## Metadata

| Field       | Value                              |
| ----------- | ---------------------------------- |
| ID          | `004-001-extract-votable-concern`  |
| Status      | `todo`                             |
| Priority    | `002` High                         |
| Created     | `2026-02-01 19:20`                 |
| Labels      | `technical-debt`, `refactor`       |

---

## Context

Code duplication found between `VotesController` and `NoteVotesController`. Both controllers have identical toggle logic differing only in the votable model (ContentItem vs Note). This is a DRY violation that increases maintenance burden.

Flay analysis identified this as mass=168 duplication.

---

## Acceptance Criteria

- [ ] Create `Votable` concern for polymorphic voting
- [ ] Refactor `VotesController` to use concern
- [ ] Refactor `NoteVotesController` to use concern
- [ ] Tests pass
- [ ] Quality gates pass

---

## Plan

1. **Create concern**: `app/controllers/concerns/votable.rb`
   - Extract common toggle logic
   - Use polymorphic association pattern

2. **Refactor controllers**
   - Include concern in both controllers
   - Override `set_votable` in each controller

3. **Update tests**
   - Ensure existing tests still pass

---

## Notes

- Similar pattern needed for comments (see note_comments vs comments)
- Files: `app/controllers/votes_controller.rb:12`, `app/controllers/note_votes_controller.rb:12`

---

## Links

- Related: `app/controllers/votes_controller.rb`
- Related: `app/controllers/note_votes_controller.rb`
