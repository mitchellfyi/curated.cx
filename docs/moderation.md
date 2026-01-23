# Moderation - Community Controls

## Overview

Curated.cx provides moderation tools for site administrators to manage community engagement. All moderation actions are **site-scoped** - bans and content moderation on Site A have no effect on Site B.

**Core Features**:
- Hide content from public view
- Lock comments on content items
- Ban users from participating

---

## Content Moderation

### Hiding Content

Content can be hidden from public view while remaining in the database for review.

**When to use**:
- Content violates community guidelines
- Spam or promotional content
- Pending review of flagged content

**How it works**:
- `hidden_at` timestamp is set when content is hidden
- `hidden_by_id` tracks which admin hid the content
- Hidden content is excluded from feeds and search

**API**:

```ruby
# Hide content
content_item.hide!(current_user)

# Unhide content
content_item.unhide!

# Check status
content_item.hidden?  # => true/false
```

**Routes**:

```
POST /admin/content_items/:id/hide
POST /admin/content_items/:id/unhide
```

### Locking Comments

Comments can be locked on specific content items to prevent new discussion.

**When to use**:
- Discussion has become unproductive
- Content is outdated or resolved
- Preventing spam on popular content

**How it works**:
- `comments_locked_at` timestamp is set when locked
- `comments_locked_by_id` tracks which admin locked comments
- Existing comments remain visible
- New comments are blocked (returns 403)

**API**:

```ruby
# Lock comments
content_item.lock_comments!(current_user)

# Unlock comments
content_item.unlock_comments!

# Check status
content_item.comments_locked?  # => true/false
```

**Routes**:

```
POST /admin/content_items/:id/lock_comments
POST /admin/content_items/:id/unlock_comments
```

---

## User Bans

Site bans prevent users from participating in a specific site's community.

### SiteBan Model

```ruby
SiteBan
  - user_id        # The banned user
  - banned_by_id   # Admin who issued the ban
  - site_id        # Site this ban applies to
  - reason         # Explanation for the ban (optional)
  - banned_at      # When the ban was issued
  - expires_at     # When the ban expires (nil = permanent)
```

### Ban Types

**Permanent bans**:
- `expires_at` is nil
- User cannot participate until manually unbanned

**Temporary bans**:
- `expires_at` is set to a future timestamp
- Ban automatically expires after the date passes

### Checking Ban Status

```ruby
# Check if user is banned from a site
user.banned_from?(site)  # => true/false

# Get active bans for a user
SiteBan.active.for_user(user)

# Get expired bans
SiteBan.expired
```

### Ban Effects

When a user is banned:
- **Cannot vote** - VotePolicy denies create
- **Cannot comment** - CommentPolicy denies create
- **Existing content remains** - Previous votes/comments are preserved

### Admin Interface

**Routes**:

```
GET    /admin/site_bans          # List all bans
GET    /admin/site_bans/new      # Ban form
POST   /admin/site_bans          # Create ban
GET    /admin/site_bans/:id      # View ban details
DELETE /admin/site_bans/:id      # Remove ban
```

---

## Rate Limiting

Rate limiting prevents abuse of community features.

### Limits

| Action   | Limit        | Period |
|----------|--------------|--------|
| Votes    | 100          | 1 hour |
| Comments | 10           | 1 hour |

### Implementation

Rate limiting uses `RateLimitable` concern with Rails.cache:

```ruby
class VotesController < ApplicationController
  include RateLimitable

  before_action -> { rate_limit!(:vote, 100, 1.hour) }
end
```

### Rate Limit Response

When rate limited, the server returns:
- **Status**: 429 Too Many Requests
- **Body**: Error message indicating rate limit exceeded

---

## Authorization

All moderation actions require appropriate permissions via Pundit policies.

### Required Roles

| Action              | Required Role |
|---------------------|---------------|
| Hide/unhide content | admin, owner  |
| Lock/unlock comments| admin, owner  |
| Create site ban     | admin, owner  |
| Remove site ban     | admin, owner  |
| View site bans      | admin, owner  |

### Policy Checks

```ruby
# Content moderation
authorize content_item, :hide?
authorize content_item, :unhide?
authorize content_item, :lock_comments?
authorize content_item, :unlock_comments?

# Site bans
authorize site_ban, :create?
authorize site_ban, :destroy?
```

---

## Multi-Tenant Isolation

All moderation is **site-scoped**:

- Bans on Site A do not affect Site B
- Hidden content on Site A is still visible on Site B (if it exists there)
- Admins can only moderate their own site(s)

```ruby
# Ban is site-specific
ban = SiteBan.create!(
  user: offending_user,
  site: Current.site,
  banned_by: admin_user
)

# User can still participate on other sites
user.banned_from?(site_a)  # => true
user.banned_from?(site_b)  # => false
```

---

## Audit Trail

All moderation actions are tracked:

| Action          | Tracked Fields              |
|-----------------|----------------------------|
| Hide content    | hidden_at, hidden_by_id    |
| Lock comments   | comments_locked_at, comments_locked_by_id |
| Ban user        | banned_at, banned_by_id, expires_at, reason |

This allows admins to review who took actions and when.

---

## Best Practices

1. **Document ban reasons** - Always provide a reason when banning users
2. **Prefer temporary bans** - Use expiring bans for first offenses
3. **Lock before hiding** - Lock comments before hiding controversial content
4. **Review hidden content** - Regularly review hidden content for appeal
5. **Consistent enforcement** - Apply community guidelines uniformly

---

*Last Updated: 2026-01-23*
