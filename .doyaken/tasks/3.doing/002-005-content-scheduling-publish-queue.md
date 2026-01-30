# Task: Content Scheduling & Publish Queue

## Metadata

| Field       | Value                                                  |
| ----------- | ------------------------------------------------------ |
| ID          | `002-005-content-scheduling-publish-queue`             |
| Status      | `todo`                                                 |
| Priority    | `002` High                                             |
| Created     | `2026-01-30 15:30`                                     |
| Started     |                                                        |
| Completed   |                                                        |
| Blocked By  |                                                        |
| Blocks      |                                                        |
| Assigned To | `worker-1` |
| Assigned At | `2026-01-30 19:19` |

---

## Context

Why does this task exist? What problem does it solve?

- **Industry Standard**: Ghost, Substack, Medium, beehiiv all support scheduled publishing. It's expected functionality for any content platform.
- **User Need**: Publishers want to queue content for optimal posting times without manual intervention.
- **Current Gap**: Curated ingests content automatically but has no scheduling for manual/curated content or for controlling when ingested content appears.
- **RICE Score**: 180 (Reach: 800, Impact: 1.5, Confidence: 100%, Effort: 0.67 person-weeks)

**Problem**: Publishers cannot schedule content to publish at specific times. All content either publishes immediately or must be manually published.

**Solution**: Add scheduled_for field to content items and listings with a background job that publishes on schedule.

---

## Acceptance Criteria

All must be checked before moving to done:

- [ ] scheduled_for datetime field on ContentItem
- [ ] scheduled_for datetime field on Listing
- [ ] Draft status with scheduled publishing
- [ ] PublishScheduledContentJob background job
- [ ] Admin UI for setting publish date/time
- [ ] Calendar view of scheduled content
- [ ] Timezone-aware scheduling per site
- [ ] Notification when scheduled content publishes
- [ ] Tests written and passing
- [ ] Quality gates pass
- [ ] Changes committed with task reference

---

## Plan

Step-by-step implementation approach:

1. **Step 1**: Add scheduled_for to ContentItem
   - Files: `db/migrate/xxx_add_scheduled_for_to_content_items.rb`
   - Actions: Add datetime field, index for efficient querying

2. **Step 2**: Add scheduled_for to Listing
   - Files: `db/migrate/xxx_add_scheduled_for_to_listings.rb`
   - Actions: Add datetime field

3. **Step 3**: Update visibility logic
   - Files: `app/models/content_item.rb`, `app/models/listing.rb`
   - Actions: Don't show content where scheduled_for > now

4. **Step 4**: Create PublishScheduledContentJob
   - Files: `app/jobs/publish_scheduled_content_job.rb`
   - Actions: Run every minute, publish due content

5. **Step 5**: Add scheduling UI in admin
   - Files: `app/views/admin/content_items/`, `app/views/admin/listings/`
   - Actions: Date/time picker, timezone selector

6. **Step 6**: Create scheduled content calendar
   - Files: `app/controllers/admin/schedule_controller.rb`
   - Actions: Calendar view showing upcoming scheduled content

7. **Step 7**: Add publish notifications
   - Files: Use ActionMailer
   - Actions: Email publisher when scheduled content goes live

8. **Step 8**: Write tests
   - Files: `spec/jobs/publish_scheduled_content_job_spec.rb`
   - Coverage: Scheduling, publishing, timezone handling

---

## Work Log

_No work started yet._

---

## Testing Evidence

_No tests run yet._

---

## Notes

- Consider optimal posting times feature later (analyze when engagement is highest)
- Support draft + scheduled states
- Allow rescheduling and unscheduling
- Use site timezone setting for display, store in UTC

---

## Links

- Research: Ghost scheduling, Substack scheduling
- Related: ContentItem model, Listing model, existing admin
