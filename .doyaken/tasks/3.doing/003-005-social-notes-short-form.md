# Task: Social Notes / Short-Form Content

## Metadata

| Field       | Value                                                  |
| ----------- | ------------------------------------------------------ |
| ID          | `003-005-social-notes-short-form`                      |
| Status      | `todo`                                                 |
| Priority    | `003` Medium                                           |
| Created     | `2026-01-30 15:30`                                     |
| Started     |                                                        |
| Completed   |                                                        |
| Blocked By  |                                                        |
| Blocks      |                                                        |
| Assigned To | `worker-1` |
| Assigned At | `2026-02-01 16:55` |

---

## Context

Why does this task exist? What problem does it solve?

- **Competitive Feature**: Substack Notes is the #1 growth source, driving 70% of new subscribers for some creators. It's a social layer on top of the newsletter platform.
- **Platform Trend**: Content platforms are adding social features to increase engagement and discoverability.
- **Network Effect**: Short-form content shared across the network drives discovery.
- **RICE Score**: 90 (Reach: 500, Impact: 2, Confidence: 75%, Effort: 0.83 person-weeks)

**Problem**: Publishers can only share long-form content items. There's no quick way to share thoughts, links, or quick updates with their audience.

**Solution**: A "Notes" feature for short-form posts that appear in a social feed, can be shared across the network, and drive subscriber growth.

---

## Acceptance Criteria

All must be checked before moving to done:

- [ ] Note model for short-form posts (280-500 char limit)
- [ ] Image/link attachment support
- [ ] Publisher's note feed on their site
- [ ] Network-wide notes feed on curated.cx hub
- [ ] Repost/share notes across sites
- [ ] Like/reaction on notes
- [ ] Notes in subscriber digest (optional)
- [ ] Tests written and passing
- [ ] Quality gates pass
- [ ] Changes committed with task reference

---

## Plan

Step-by-step implementation approach:

1. **Step 1**: Create Note model
   - Files: `app/models/note.rb`, `db/migrate/xxx_create_notes.rb`
   - Actions: body, user_id, site_id, images, link_preview, repost_of_id

2. **Step 2**: Create note feed on tenant sites
   - Files: `app/controllers/notes_controller.rb`, views
   - Actions: Note feed, create note, show single note

3. **Step 3**: Add link preview extraction
   - Files: `app/services/link_preview_service.rb`
   - Actions: Fetch OG data for linked URLs

4. **Step 4**: Add reactions to notes
   - Files: Extend Vote model or create NoteReaction
   - Actions: Like/react to notes

5. **Step 5**: Create network notes feed
   - Files: Update curated.cx hub
   - Actions: Aggregate notes across network

6. **Step 6**: Add repost functionality
   - Files: Note model, controllers
   - Actions: Repost notes with attribution

7. **Step 7**: Optional digest inclusion
   - Files: Update digest email templates
   - Actions: Include recent notes in digest

8. **Step 8**: Write tests
   - Files: `spec/models/note_spec.rb`, `spec/features/notes_spec.rb`
   - Coverage: CRUD, reposts, reactions, feed

---

## Work Log

_No work started yet._

---

## Testing Evidence

_No tests run yet._

---

## Notes

- This complements but doesn't replace ContentItem (which is for curated/ingested content)
- Consider character limit - Substack Notes is generous, Twitter-style is 280
- Link previews can use existing MetaInspector
- Moderation: Use existing Flag model

---

## Links

- Research: Substack Notes growth impact
- Related: ContentItem, Vote, NetworkFeedService
