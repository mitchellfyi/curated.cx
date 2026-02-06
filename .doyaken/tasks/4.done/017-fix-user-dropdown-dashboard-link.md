# Task: Fix or Remove Dashboard Link from User Account Dropdown

## Metadata

| Field       | Value                                                  |
| ----------- | ------------------------------------------------------ |
| ID          | `017-fix-user-dropdown-dashboard-link`                 |
| Status      | `todo`                                                 |
| Priority    | `003` Medium                                           |
| Created     | `2026-02-06 12:00`                                     |
| Started     |                                                        |
| Completed   |                                                        |
| Blocked By  |                                                        |
| Blocks      |                                                        |
| Assigned To |                                                        |
| Assigned At |                                                        |

---

## Context

The user account dropdown (in `app/views/shared/_navigation.html.erb`) contains a "Dashboard" link pointing to `dashboard_path`. The `DashboardController` has `skip_after_action :verify_authorized` with the comment "User dashboard shows current_user's own data". This link needs to either:

1. Work properly - if the user dashboard exists and is useful, make sure it renders correctly and provides value
2. Be removed - if there's no meaningful user dashboard distinct from the homepage or admin dashboard

The dropdown currently shows: Dashboard, My Saves, My Submissions, Admin (conditional), Settings, Logout. Both desktop and mobile menus have this link.

---

## Acceptance Criteria

- [ ] Determine if user dashboard (`dashboard_path`) serves a purpose distinct from the admin dashboard
- [ ] If keeping: ensure the dashboard page renders correctly with useful user-specific content
- [ ] If keeping: ensure authorization is appropriate (users see only their own data)
- [ ] If removing: remove "Dashboard" link from both desktop and mobile dropdown menus
- [ ] If removing: redirect `dashboard_path` to appropriate fallback (home or admin)
- [ ] Verify no broken links in navigation after change
- [ ] Tests updated to reflect the change
- [ ] Quality gates pass
- [ ] Changes committed with task reference

---

## Notes

- Reference: `app/views/shared/_navigation.html.erb` lines 147 (desktop) and mobile menu section
- Reference: `app/controllers/dashboard_controller.rb` (not admin - the public-facing one)
- The admin dashboard is at `/admin` via `admin_root_path` - this is a separate "user" dashboard
- Check if `dashboard_path` route exists and what controller/action it maps to
