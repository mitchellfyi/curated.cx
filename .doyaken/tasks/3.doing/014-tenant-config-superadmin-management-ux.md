# Task: Admin Tenant Config and Super Admin Multi-Tenant Management UX

## Metadata

| Field       | Value                                                  |
| ----------- | ------------------------------------------------------ |
| ID          | `014-tenant-config-superadmin-management-ux`           |
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

Admin needs to be able to configure everything related to their tenant (branding, settings, domains, features), and super admin needs an enhanced view to manage all tenants efficiently - observing status, health, and configuration across the platform.

Currently:
- Tenant model has: title, slug, hostname, logo_url, favicon_url, primary_color, secondary_color, meta_title, meta_description, twitter_handle, analytics_id, custom_css, custom_head_html, settings (JSONB)
- Super admin can list/edit/impersonate tenants at `/admin/tenants`
- Tenant admin manages their own settings via Sites & Domains
- Missing: comprehensive tenant config UI, cross-tenant status dashboard for super admin

---

## Acceptance Criteria

### Tenant Admin Config
- [ ] Tenant admin can configure all tenant attributes from a single settings page
- [ ] Branding settings: logo, favicon, primary/secondary colors, custom CSS
- [ ] SEO settings: meta title, meta description, analytics ID
- [ ] Social settings: twitter handle
- [ ] Domain management: add/remove/verify domains
- [ ] Feature flags/settings (from JSONB settings column)
- [ ] Organized into logical tabs or sections (not one long form)
- [ ] Validation feedback on save

### Super Admin Management
- [ ] Super admin dashboard shows all tenants with key health metrics
- [ ] Per-tenant summary: content count, user count, last import, job health, active sources
- [ ] Status indicators: healthy/warning/degraded per tenant
- [ ] Quick actions: impersonate, edit, pause/resume workflows per tenant
- [ ] Cross-tenant search for users, content, sources
- [ ] Ability to compare tenants (resource usage, growth)
- [ ] Easy navigation between tenant views and global view
- [ ] Super admin can create new tenants

### UX
- [ ] Clean, scannable layout - information hierarchy prioritizes status/health
- [ ] Consistent with existing admin design patterns
- [ ] Mobile-friendly admin views
- [ ] Loading states for data-heavy pages

### Quality
- [ ] Tests written and passing for new controllers/actions
- [ ] Request specs for tenant config endpoints
- [ ] Request specs for super admin tenant management
- [ ] Quality gates pass
- [ ] Changes committed with task reference

---

## Notes

- Reference: `app/controllers/admin/tenants_controller.rb` for existing super admin tenant management
- Reference: `app/controllers/admin/sites_controller.rb` for existing domain management
- Reference: `app/models/tenant.rb` for tenant attributes
- Reference: `app/views/admin/shared/_sidebar.html.erb` for nav patterns
- Consider using Turbo Frames for tab switching in tenant config
- If any manual server/infrastructure work is needed (DNS setup, environment variables), raise a GitHub issue
