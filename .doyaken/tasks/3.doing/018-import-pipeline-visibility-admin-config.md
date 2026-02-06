# Task: Improve Import Pipeline Visibility and Admin Configuration

## Metadata

| Field       | Value                                                  |
| ----------- | ------------------------------------------------------ |
| ID          | `018-import-pipeline-visibility-admin-config`          |
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

The import pipeline currently has sources (`/admin/sources`) and import runs (`/admin/import_runs`) but the admin experience needs improvement to provide clear visibility into what jobs run, when, what they do, and what they've done. Admins should be able to fully configure the pipeline with sensible defaults per tenant.

Current state:
- Sources have basic config: name, kind, enabled, SerpAPI settings, schedule (interval_minutes)
- Import runs show: source, time, duration, status, items created/updated/failed
- `ProcessDueSourcesJob` orchestrates: checks each source's `next_run_at` and queues appropriate jobs
- Job types: `FetchRssJob`, `FetchSerpApiNewsJob`, `SerpApiJobsIngestionJob`, `SerpApiYoutubeIngestionJob`
- `WorkflowPause` system can pause imports globally, per-tenant, or per-source
- No timeline/schedule view showing when jobs will next run
- No clear explanation of what each job type does

---

## Acceptance Criteria

### Pipeline Visibility
- [ ] Pipeline overview page showing all sources with their schedule and next run time
- [ ] Visual timeline/schedule showing when each source will next be processed
- [ ] Clear explanation of what each source kind does (RSS fetches feeds, SerpAPI News searches Google News, etc.)
- [ ] Per-source history: last N runs with status, duration, items processed
- [ ] Per-source health indicator: healthy (last run succeeded), warning (intermittent failures), failing (consecutive failures)
- [ ] Show the full chain: Source → Job → Import Run → Content Items created
- [ ] Failed run details: error message, stack trace (for admins), retry option
- [ ] Real-time status: which jobs are currently running

### Admin Configuration
- [ ] Source schedule is configurable with human-friendly UI (not raw minutes)
- [ ] Frequency presets: every 15 min, 30 min, hourly, every 6 hours, daily, weekly
- [ ] Custom interval option for advanced users
- [ ] Per-source pause/resume with reason
- [ ] Per-source "Run Now" button with confirmation
- [ ] Configurable retry settings per source (max retries, backoff)
- [ ] Enable/disable individual source kinds per tenant

### Sensible Defaults
- [ ] New tenants get sensible default schedule (e.g. RSS: hourly, SerpAPI: every 6 hours)
- [ ] Default rate limits per source kind
- [ ] Default max results per source kind
- [ ] Defaults are configurable at tenant level (not hardcoded)
- [ ] Document what defaults are and why

### Notifications
- [ ] Surface import failures in the admin dashboard prominently
- [ ] Optional: configurable alerts when a source has N consecutive failures

### Quality
- [ ] Tests for pipeline overview page
- [ ] Tests for source configuration changes
- [ ] Tests for schedule/frequency logic
- [ ] Quality gates pass
- [ ] Changes committed with task reference

---

## Notes

- Reference: `app/controllers/admin/sources_controller.rb` for source CRUD + `run_now` action
- Reference: `app/controllers/admin/import_runs_controller.rb` for run listing
- Reference: `app/views/admin/sources/_form.html.erb` for current source form (interval_minutes with JS conversion)
- Reference: `app/jobs/process_due_sources_job.rb` for orchestration logic
- Reference: `app/models/source.rb` for source model and scheduling attributes
- Reference: `app/services/workflow_pause_service.rb` for pause system
- Consider using Turbo Frames for real-time job status updates
- The schedule interval is stored as seconds internally but displayed as minutes in the form
