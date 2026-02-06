# Task: Make Admin Dashboard Consistent with Navigation

## Metadata

| Field       | Value                                                  |
| ----------- | ------------------------------------------------------ |
| ID          | `010-admin-dashboard-navigation-consistency`           |
| Status      | `todo`                                                 |
| Priority    | `002` High                                             |
| Created     | `2026-02-06 12:00`                                     |
| Started     |                                                        |
| Completed   |                                                        |
| Blocked By  |                                                        |
| Blocks      |                                                        |
| Assigned To |                                                        |
| Assigned At |                                                        |

---

## Context

The admin dashboard (`/admin`) should provide a consistent overview that aligns with everything accessible via the sidebar navigation. Currently the sidebar has sections for Content, Sources, Commerce, Boosts/Network, Subscribers, Community, Moderation, Taxonomy, System, and Settings - but the dashboard may not surface summary cards or quick links for all of these areas.

- The dashboard should act as a hub that gives admins a snapshot of every section available in the navigation
- Each nav section should have a corresponding summary widget/card on the dashboard
- Counts, statuses, and quick action links should be consistent between nav badges and dashboard stats

---

## Acceptance Criteria

- [ ] Audit current dashboard widgets vs sidebar navigation sections
- [ ] Dashboard has a summary card/widget for every top-level sidebar section
- [ ] Content section: items, listings, submissions (pending count), notes
- [ ] Sources section: enabled sources count, recent import status
- [ ] Commerce section: digital products, affiliate clicks, live streams
- [ ] Boosts/Network section: active boosts, earnings summary, pending payouts
- [ ] Subscribers section: total subscribers, active sequences, referrals
- [ ] Community section: discussions count, hidden comments count
- [ ] Moderation section: open flags, active site bans
- [ ] Taxonomy section: categories, taxonomies, tagging rules counts
- [ ] System section: observability status, background job health, import runs
- [ ] Settings section: sites/domains status
- [ ] Dashboard cards link to their respective admin pages
- [ ] Badge counts on dashboard match sidebar badge counts
- [ ] Tests written and passing for dashboard controller
- [ ] Quality gates pass
- [ ] Changes committed with task reference

---

## Notes

- Reference: `app/controllers/admin/dashboard_controller.rb`, `app/views/admin/dashboard/`
- Reference: `app/views/admin/shared/_sidebar.html.erb` for nav structure
- Super admin dashboard should additionally show cross-tenant summary
