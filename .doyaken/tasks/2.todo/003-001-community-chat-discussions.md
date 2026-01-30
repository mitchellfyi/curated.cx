# Task: Community Chat & Discussions

## Metadata

| Field       | Value                                                  |
| ----------- | ------------------------------------------------------ |
| ID          | `003-001-community-chat-discussions`                   |
| Status      | `todo`                                                 |
| Priority    | `003` Medium                                           |
| Created     | `2026-01-30 15:30`                                     |
| Started     |                                                        |
| Completed   |                                                        |
| Blocked By  |                                                        |
| Blocks      |                                                        |
| Assigned To |                                                        |
| Assigned At |                                                        |

---

## Context

Why does this task exist? What problem does it solve?

- **Competitive Feature**: Substack Chat is "one of the most underrated features" making publications feel like communities. Ghost added community features in recent updates.
- **Platform Trend**: Content platforms are evolving from "one-way broadcast" to "two-way community engagement."
- **User Value**: Readers want to discuss content and connect with each other, not just passively consume.
- **RICE Score**: 120 (Reach: 600, Impact: 2, Confidence: 80%, Effort: 0.8 person-weeks)

**Problem**: Curated has comments on content items but no dedicated community space for ongoing discussions between readers.

**Solution**: A chat/discussion feature where publishers can create topic-based channels and readers can engage in real-time or async conversations.

---

## Acceptance Criteria

All must be checked before moving to done:

- [ ] Discussion model for topic threads
- [ ] DiscussionPost model for messages
- [ ] Discussion channels per site (configurable by admin)
- [ ] Real-time updates using Turbo Streams
- [ ] Discussion notifications for participants
- [ ] Moderation tools (delete, lock, pin)
- [ ] User mentions (@username)
- [ ] Discussion in subscriber-only or public mode
- [ ] Tests written and passing
- [ ] Quality gates pass
- [ ] Changes committed with task reference

---

## Plan

Step-by-step implementation approach:

1. **Step 1**: Create Discussion model
   - Files: `app/models/discussion.rb`, `db/migrate/xxx_create_discussions.rb`
   - Actions: title, site_id, user_id, visibility, pinned, locked

2. **Step 2**: Create DiscussionPost model
   - Files: `app/models/discussion_post.rb`
   - Actions: discussion_id, user_id, body, parent_id (threading)

3. **Step 3**: Create Discussion controllers and views
   - Files: `app/controllers/discussions_controller.rb`, `app/views/discussions/`
   - Actions: CRUD, real-time via Turbo Streams

4. **Step 4**: Add to site navigation
   - Files: Site layout, navigation partials
   - Actions: "Discussions" or "Community" link

5. **Step 5**: Add moderation tools
   - Files: Admin controllers, discussion views
   - Actions: Lock, pin, delete discussions and posts

6. **Step 6**: Add notifications
   - Files: Notification service, mailers
   - Actions: Notify on replies, mentions

7. **Step 7**: Write tests
   - Files: `spec/models/discussion_spec.rb`, `spec/features/discussions_spec.rb`
   - Coverage: CRUD, threading, moderation, real-time

---

## Work Log

_No work started yet._

---

## Testing Evidence

_No tests run yet._

---

## Notes

- Use Hotwire/Turbo for real-time without complex WebSocket setup
- Consider rate limiting to prevent spam
- Integrate with existing Flag model for reporting
- Start simple, add features like reactions later

---

## Links

- Research: Substack Chat, Ghost community features
- Related: Comment model, Flag model, existing moderation
