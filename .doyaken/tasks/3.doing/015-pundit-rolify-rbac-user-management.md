# Task: Full RBAC with Pundit/Rolify - User Management, Roles & Invitations

## Metadata

| Field       | Value                                                  |
| ----------- | ------------------------------------------------------ |
| ID          | `015-pundit-rolify-rbac-user-management`               |
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

Pundit (v2.3) and Rolify (v6.0) are already installed and partially wired up. `ApplicationController` includes `Pundit::Authorization` with `verify_authorized` and `verify_policy_scoped` after_actions. Rolify provides 4 tenant-scoped roles (`owner` level 4, `admin` level 3, `editor` level 2, `viewer` level 1) plus a global `admin` boolean on the User model. 24 policy files exist in `app/policies/`.

What's missing is a complete, audited RBAC system where:
- Every controller action is properly authorized (some currently skip verification)
- Admins can manage users and their roles from the admin UI
- Admins can invite new users to their tenant with a specific role
- Role permissions are clearly defined and consistently enforced across all resources

---

## Acceptance Criteria

### Audit & Fix Existing Authorization
- [ ] Audit all controllers - identify which skip or miss Pundit authorization
- [ ] Ensure every admin controller action calls `authorize` appropriately
- [ ] Ensure every public controller uses policy scopes where applicable
- [ ] Review all 24 policies for consistency with role hierarchy
- [ ] Document the permission matrix: which role can do what across all resources

### User Management Admin UI
- [ ] Admin users page (`/admin/users`) lists all tenant users with their roles
- [ ] Show user details: email, role, last sign in, created at, status
- [ ] Admins can change a user's role (within their authority - can't grant higher than own role)
- [ ] Admins can remove a user's access to their tenant
- [ ] Owners can promote/demote admins
- [ ] Super admins can manage users across all tenants
- [ ] Bulk actions: assign role, remove access

### User Invitations
- [ ] Admin can invite users by email with a pre-assigned role
- [ ] Invitation creates a pending record (or uses Devise Invitable if appropriate)
- [ ] Invited user receives email with sign-up/accept link
- [ ] On acceptance, user is assigned the specified role on the tenant
- [ ] Admin can see pending invitations and resend/cancel them
- [ ] Invitation expires after configurable period (default: 7 days)

### Role-Based UI
- [ ] Navigation and UI elements respect roles (editors don't see settings, viewers don't see edit buttons)
- [ ] Sidebar sections show/hide based on user's role
- [ ] Unauthorized access shows friendly error, not stack trace

### Quality
- [ ] Policy specs for all policies covering all roles
- [ ] Request specs for user management CRUD
- [ ] Request specs for invitation flow
- [ ] Tests for role hierarchy enforcement
- [ ] Quality gates pass
- [ ] Changes committed with task reference

---

## Notes

- Reference: `app/policies/application_policy.rb` for base policy pattern
- Reference: `app/models/role.rb` for role definitions and hierarchy
- Reference: `app/controllers/concerns/admin_access.rb` for access control
- Reference: `app/controllers/admin/users_controller.rb` for existing user admin
- Reference: `app/views/admin/shared/_sidebar.html.erb` for nav role gating
- Consider `devise_invitable` gem for invitation flow, or roll a simple invite model
- Controllers that currently skip authorization: `DashboardController`, `DownloadsController`, `AffiliateRedirectsController`, `DomainNotConnectedController`
