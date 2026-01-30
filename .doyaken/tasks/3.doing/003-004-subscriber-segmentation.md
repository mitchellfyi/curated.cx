# Task: Subscriber Segmentation & Dynamic Content

## Metadata

| Field       | Value                                                  |
| ----------- | ------------------------------------------------------ |
| ID          | `003-004-subscriber-segmentation`                      |
| Status      | `todo`                                                 |
| Priority    | `003` Medium                                           |
| Created     | `2026-01-30 15:30`                                     |
| Started     |                                                        |
| Completed   |                                                        |
| Blocked By  |                                                        |
| Blocks      |                                                        |
| Assigned To | `worker-1` |
| Assigned At | `2026-01-30 23:22` |

---

## Context

Why does this task exist? What problem does it solve?

- **Competitive Feature**: beehiiv offers audience segmentation by location, interests, engagement level. Kit has advanced segmentation with subscriber scoring. This enables targeted content.
- **Industry Trend**: Hyper-personalization at scale is a 2026 mega-trend (40% growth expected).
- **User Value**: Publishers send the same digest to all subscribers regardless of interests or engagement level.
- **RICE Score**: 96 (Reach: 800, Impact: 1.5, Confidence: 80%, Effort: 1 person-week)

**Problem**: Publishers cannot segment their subscriber list or send targeted content to specific groups. All subscribers receive identical communications.

**Solution**: Subscriber tagging and segmentation system with dynamic content blocks that render differently based on segment.

---

## Acceptance Criteria

All must be checked before moving to done:

- [ ] SubscriberSegment model for defining segments
- [ ] Segment rules (interests, engagement, location, signup date)
- [ ] Manual tagging of subscribers
- [ ] Auto-segmentation based on behavior
- [ ] Segment selection when sending digests
- [ ] Segment analytics (size, growth, engagement)
- [ ] A/B testing support per segment (future)
- [ ] Tests written and passing
- [ ] Quality gates pass
- [ ] Changes committed with task reference

---

## Plan

Step-by-step implementation approach:

1. **Step 1**: Create SubscriberSegment model
   - Files: `app/models/subscriber_segment.rb`, `db/migrate/xxx_create_subscriber_segments.rb`
   - Actions: name, site_id, rules (JSONB), auto_update

2. **Step 2**: Create SubscriberTag for manual tagging
   - Files: `app/models/subscriber_tag.rb`
   - Actions: Many-to-many with DigestSubscription

3. **Step 3**: Create SegmentationService
   - Files: `app/services/segmentation_service.rb`
   - Actions: Evaluate rules, return matching subscribers

4. **Step 4**: Add segment selection to digest sending
   - Files: Update digest admin, SendDigestEmailsJob
   - Actions: Filter recipients by segment

5. **Step 5**: Add auto-segmentation rules
   - Files: Update segmentation service
   - Actions: Active (opened in 30 days), Inactive, New, etc.

6. **Step 6**: Create segment analytics
   - Files: Admin dashboard
   - Actions: Size, growth rate, open rates per segment

7. **Step 7**: Write tests
   - Files: `spec/services/segmentation_service_spec.rb`
   - Coverage: Rule evaluation, auto-segmentation, filtering

---

## Work Log

_No work started yet._

---

## Testing Evidence

_No tests run yet._

---

## Notes

- Start with basic segments: Active, Inactive, New, Power Users
- Engagement tracking needed (email opens, clicks)
- Consider privacy regulations (GDPR) for location-based segments
- Future: Dynamic content blocks that change based on viewer segment

---

## Links

- Research: beehiiv segmentation, Kit subscriber scoring
- Related: DigestSubscription, email digest system
