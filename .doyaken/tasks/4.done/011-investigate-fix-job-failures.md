# Task: Investigate Job Failures and Fix Them

## Metadata

| Field       | Value                                                  |
| ----------- | ------------------------------------------------------ |
| ID          | `011-investigate-fix-job-failures`                     |
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

Background jobs (SolidQueue) may be failing silently or with errors that aren't being surfaced properly. This task requires investigating all job failure modes, identifying recurring failures, and fixing root causes.

- Jobs include: RSS fetching, SerpAPI ingestion, AI editorialisation, metadata scraping, email digests, sequence processing, boost clicks, referrals, scheduled publishing
- ApplicationJob base class retries on `ExternalServiceError`, `DnsError`, `ActiveRecord::Deadlocked` and discards on `ConfigurationError`, `ActiveRecord::RecordNotFound`, `AiInvalidResponseError`, `AiConfigurationError`
- MissionControl UI at `/admin/jobs` provides job monitoring
- Observability dashboard shows failed import/editorialisation counts

---

## Acceptance Criteria

- [ ] Check MissionControl for failed/errored jobs - document what's failing
- [ ] Review SolidQueue error logs for recurring failures
- [ ] Check import_runs with `status: :failed` - identify patterns
- [ ] Check editorialisations with `status: :failed` - identify patterns
- [ ] Fix root causes of any identified failures
- [ ] Verify retry logic is appropriate for each job type
- [ ] Ensure job failures are properly surfaced in observability dashboard
- [ ] Add better error context/logging where failures are opaque
- [ ] Tests written and passing for any fixes
- [ ] Quality gates pass
- [ ] Changes committed with task reference

---

## Notes

- Key job files in `app/jobs/`
- Check `ProcessDueSourcesJob` - this orchestrates all source imports
- Check if `WorkflowPause` is inadvertently blocking jobs
- If any failures require manual infrastructure intervention (e.g. DNS, API keys, server config), raise a GitHub issue for the human to handle
- Reference: MissionControl at `/admin/jobs`, health endpoint at `/admin/health`
