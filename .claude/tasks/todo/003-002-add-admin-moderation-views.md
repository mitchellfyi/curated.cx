# Task: Add Admin Moderation Views

## Metadata

| Field | Value |
|-------|-------|
| ID | `003-002-add-admin-moderation-views` |
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

The community primitives task (002-006) implemented admin controllers for site bans and content moderation, but the view templates were not created. Admins need UI to manage bans and moderate content.

This is a follow-up from task 002-006-community-primitives.

---

## Acceptance Criteria

- [ ] `app/views/admin/site_bans/index.html.erb` - List all site bans
- [ ] `app/views/admin/site_bans/show.html.erb` - View ban details
- [ ] `app/views/admin/site_bans/new.html.erb` - Create new ban form
- [ ] `app/views/admin/site_bans/_form.html.erb` - Ban form partial
- [ ] Moderation buttons on content items (hide/unhide, lock/unlock)
- [ ] Visual indicators for hidden content and locked comments in admin
- [ ] Turbo Stream templates for moderation actions
- [ ] Quality gates pass

---

## Plan

1. Create site_bans views (index, show, new, _form)
2. Add moderation buttons to admin content item views
3. Create Turbo Stream templates for moderation actions
4. Add visual badges for moderation status
5. Style with Tailwind CSS
6. Add i18n translations
7. Test admin flows manually

---

## Work Log

### 2026-01-23 09:44 - Task Created

Created as follow-up from 002-006-community-primitives review phase.

---

## Testing Evidence

(To be completed)

---

## Notes

- Consider adding bulk moderation actions
- May want moderation log/history view
- Confirmation dialogs for ban actions

---

## Links

- Related: `002-006-community-primitives` - Original implementation
