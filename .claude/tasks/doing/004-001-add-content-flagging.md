# Task: Add Content Flagging/Reporting Feature

## Metadata

| Field | Value |
|-------|-------|
| ID | `004-001-add-content-flagging` |
| Status | `todo` |
| Priority | `004` Low |
| Created | `2026-01-23 09:44` |
| Started | |
| Completed | |
| Blocked By | `003-001-add-comments-views` |
| Blocks | |
| Assigned To | `worker-1` |
| Assigned At | `2026-01-24 17:30` |

---

## Context

Users should be able to flag/report content and comments that violate community guidelines. This enables community-driven moderation and creates a queue for admins to review.

This was identified as a potential enhancement during the 002-006-community-primitives review.

---

## Acceptance Criteria

- [ ] Flag model (user, flaggable, reason, status)
- [ ] Users can flag content items
- [ ] Users can flag comments
- [ ] One flag per user per item
- [ ] Admin moderation queue for flagged content
- [ ] Flag count threshold for auto-hide (configurable per site)
- [ ] Admin can resolve/dismiss flags
- [ ] Notification to admins on new flags
- [ ] Quality gates pass

---

## Plan

1. Create Flag model (polymorphic flaggable)
2. Add FlagsController for user flagging
3. Create admin moderation queue view
4. Implement auto-hide threshold
5. Add notification system integration
6. Write tests
7. Update documentation

---

## Work Log

### 2026-01-23 09:44 - Task Created

Identified as enhancement during 002-006-community-primitives review.
Notes section mentioned: "Consider adding report/flag functionality later"

---

## Testing Evidence

(To be completed)

---

## Notes

- Consider different flag categories (spam, harassment, misinformation, etc.)
- May want to track repeat offenders
- Could integrate with automated moderation tools

---

## Links

- Related: `002-006-community-primitives` - Original implementation
- Related: `docs/moderation.md` - Moderation documentation
