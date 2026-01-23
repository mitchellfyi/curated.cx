# Task: Implement Community Primitives

## Metadata

| Field | Value |
|-------|-------|
| ID | `002-006-community-primitives` |
| Status | `todo` |
| Priority | `002` High |
| Created | `2025-01-23 00:05` |
| Started | |
| Completed | |
| Blocked By | `002-005-public-feed` |
| Blocks | `002-007-monetisation-basics` |

---

## Context

Community engagement is core to the platform. Users need to interact with content through voting and comments. Site admins need moderation tools.

User features:
- Upvote ContentItems
- Comment on ContentItems

Admin features:
- Hide content
- Lock comments
- Ban users (site-local)

Everything is scoped to Site (multi-tenant).

---

## Acceptance Criteria

- [ ] Vote model exists (user, content_item, value)
- [ ] Comment model exists (user, content_item, body, parent_id for threading)
- [ ] Users can upvote (toggle on/off)
- [ ] Users can comment (create, edit own)
- [ ] Threaded/nested comments supported
- [ ] Vote counts displayed on content cards
- [ ] Comment counts displayed on content cards
- [ ] Rate limiting on votes (e.g., 100/hour)
- [ ] Rate limiting on comments (e.g., 10/hour)
- [ ] Admin can hide ContentItem (sets hidden_at)
- [ ] Admin can lock comments on ContentItem
- [ ] Admin can ban user from Site (SiteBan model)
- [ ] Banned users cannot vote or comment
- [ ] All models scoped to Site
- [ ] Tests cover scoping and permissions
- [ ] `docs/moderation.md` documents controls
- [ ] Quality gates pass
- [ ] Changes committed with task reference

---

## Plan

1. **Create Vote model**
   - Fields: site_id, user_id, content_item_id, value (+1/-1), created_at
   - Unique constraint: [site_id, user_id, content_item_id]
   - Counter cache on ContentItem (votes_count)
   - Scoped to Site

2. **Create Comment model**
   - Fields: site_id, user_id, content_item_id, parent_id, body, edited_at
   - Ancestry or closure_tree for threading
   - Counter cache on ContentItem (comments_count)
   - Scoped to Site

3. **Create SiteBan model**
   - Fields: site_id, user_id, reason, banned_by_id, banned_at, expires_at
   - Scoped to Site

4. **Add moderation fields to ContentItem**
   - hidden_at, hidden_by_id
   - comments_locked_at, comments_locked_by_id

5. **Implement voting**
   - API endpoint for toggle
   - Optimistic UI update
   - Rate limiting (Rack::Attack or custom)

6. **Implement comments**
   - Create/edit endpoints
   - Threaded display
   - Rate limiting

7. **Implement moderation UI**
   - Admin actions on content cards
   - Ban management in admin panel
   - Moderation log for audit

8. **Add permission checks**
   - Check SiteBan before allowing actions
   - Check comments_locked before allowing new comments
   - Filter hidden content from public feed

9. **Write tests**
   - Vote toggle behavior
   - Comment threading
   - Rate limit enforcement
   - Ban enforcement
   - Tenant isolation

10. **Write documentation**
    - `docs/moderation.md`
    - Available controls
    - Best practices

---

## Work Log

(To be filled during implementation)

---

## Testing Evidence

(To be filled during implementation)

---

## Notes

- Consider adding report/flag functionality later
- May want moderation queue for flagged content
- Reputation system could be added (earned by contributions)
- Consider email notifications for replies

---

## Links

- Dependency: `002-005-public-feed`
- Mission: `MISSION.md` - Community layer
