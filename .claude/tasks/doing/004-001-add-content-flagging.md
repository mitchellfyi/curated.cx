# Task: Add Content Flagging/Reporting Feature

## Metadata

| Field | Value |
|-------|-------|
| ID | `004-001-add-content-flagging` |
| Status | `doing` |
| Priority | `004` Low |
| Created | `2026-01-23 09:44` |
| Started | `2026-01-24 17:30` |
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

### 2026-01-24 18:15 - Implementation Complete

**Commits Made:**
1. `073f5fd` - Add Flag model with migration and validations
2. `f545038` - Add Flag factory
3. `8a75978` - Add flags associations to related models
4. `45cd5c6` - Add FlagPolicy for authorization
5. `9cfb2a8` - Add FlagsController for user flag creation
6. `8c3a4cd` - Add Admin::FlagsController for moderation queue
7. `0b3b44c` - Add routes for flags
8. `c8c5f9a` - Add FlagMailer for admin notifications
9. `b8dc7f7` - Add flag button partial and Turbo Stream response
10. `1b7efeb` - Add admin flags views (index/show/turbo streams)
11. `760dba3` - Add i18n translations for flags feature
12. `65eb95f` - Integrate flag button into content card and comment views

**Files Created:**
- `db/migrate/20260124100001_create_flags.rb` - Migration for flags table
- `app/models/flag.rb` - Flag model with validations, scopes, callbacks
- `spec/factories/flags.rb` - Factory with traits
- `app/policies/flag_policy.rb` - Authorization policy
- `app/controllers/flags_controller.rb` - User-facing flag creation
- `app/controllers/admin/flags_controller.rb` - Admin moderation queue
- `app/mailers/flag_mailer.rb` - Admin notification mailer
- `app/views/flag_mailer/new_flag_notification.{html,text}.erb` - Email templates
- `app/views/flags/_flag_button.html.erb` - Reusable flag button partial
- `app/views/flags/create.turbo_stream.erb` - Turbo Stream response
- `app/views/admin/flags/{index,show}.html.erb` - Admin views
- `app/views/admin/flags/{resolve,dismiss}.turbo_stream.erb` - Admin Turbo Streams

**Files Modified:**
- `app/models/content_item.rb` - Added flags association
- `app/models/comment.rb` - Added flags association
- `app/models/user.rb` - Added flags and reviewed_flags associations
- `app/models/site.rb` - Added flags association and moderation settings
- `config/routes.rb` - Added flag routes (user and admin)
- `config/locales/en.yml` - Added i18n translations
- `app/views/feed/_content_card.html.erb` - Added flag button integration
- `app/views/comments/_comment.html.erb` - Added flag button integration

**Features Implemented:**
- Flag model with polymorphic flaggable (ContentItem, Comment)
- Reason enum: spam, harassment, misinformation, inappropriate, other
- Status enum: pending, reviewed, dismissed, action_taken
- Scoped uniqueness validation (one flag per user per item)
- Auto-hide threshold via Site.setting("moderation.flag_threshold")
- Admin notification emails via FlagMailer
- Rate limiting on flag creation (20/hour)
- Turbo Stream responses for inline UI updates
- Admin moderation queue with resolve/dismiss actions

**Next: Testing phase**

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
