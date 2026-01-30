# Task: Live Video Streaming Integration

## Metadata

| Field       | Value                                                  |
| ----------- | ------------------------------------------------------ |
| ID          | `003-002-live-video-streaming`                         |
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

- **Competitive Feature**: Substack calls live video "the highest-leverage growth tool on the platform right now" because it sends notifications to the entire subscriber list with no algorithm.
- **Platform Evolution**: Substack and beehiiv are evolving into multimedia hubs (podcasts, video).
- **Engagement**: Live video drives real-time engagement and community connection.
- **RICE Score**: 90 (Reach: 300, Impact: 3, Confidence: 75%, Effort: 0.75 person-weeks)

**Problem**: Publishers have no way to do live video or webinars within the platform. They must use external tools and manually notify subscribers.

**Solution**: Integration with a live video service (Mux, Cloudflare Stream, or YouTube Live) with built-in subscriber notifications and replay hosting.

---

## Acceptance Criteria

All must be checked before moving to done:

- [ ] LiveStream model for scheduling and tracking streams
- [ ] Integration with streaming provider (Mux or similar)
- [ ] Subscriber notification when going live
- [ ] Embeddable live player on site
- [ ] Automatic replay saving after stream ends
- [ ] Schedule live events in advance
- [ ] Live chat during stream (can use Discussion feature)
- [ ] Analytics (viewers, duration, peak concurrent)
- [ ] Tests written and passing
- [ ] Quality gates pass
- [ ] Changes committed with task reference

---

## Plan

Step-by-step implementation approach:

1. **Step 1**: Research and select streaming provider
   - Compare: Mux, Cloudflare Stream, YouTube Live API
   - Decision: Cost, ease of integration, features

2. **Step 2**: Create LiveStream model
   - Files: `app/models/live_stream.rb`, `db/migrate/xxx_create_live_streams.rb`
   - Actions: title, scheduled_at, started_at, ended_at, stream_key, playback_id, status

3. **Step 3**: Create streaming service
   - Files: `app/services/live_stream_service.rb`
   - Actions: Create stream, get playback URL, handle webhooks

4. **Step 4**: Create admin stream management
   - Files: `app/controllers/admin/live_streams_controller.rb`
   - Actions: Schedule, start, end streams

5. **Step 5**: Create viewer experience
   - Files: `app/controllers/live_streams_controller.rb`, `app/views/live_streams/`
   - Actions: Embed player, show live status, replay

6. **Step 6**: Add subscriber notifications
   - Files: Mailer, notification job
   - Actions: Notify when stream goes live

7. **Step 7**: Write tests
   - Files: `spec/models/live_stream_spec.rb`, `spec/services/live_stream_service_spec.rb`
   - Coverage: Scheduling, notifications, playback

---

## Work Log

_No work started yet._

---

## Testing Evidence

_No tests run yet._

---

## Notes

- Mux offers simple RTMP ingestion and HLS playback
- Consider starting with YouTube Live embed (simpler) before native integration
- Automatic clip creation (like Substack) is a future enhancement
- Cost consideration: streaming is expensive at scale

---

## Links

- Research: Substack live video, Mux documentation
- Related: DigestSubscription for notifications
