# Task: Add AI Usage Info to Main Admin Dashboard

## Metadata

| Field       | Value                                                  |
| ----------- | ------------------------------------------------------ |
| ID          | `012-ai-usage-info-admin-dashboard`                    |
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

The observability section already has a dedicated AI usage page (`/admin/observability/ai_usage`) with detailed cost/token tracking via `AiUsageTracker`, and SerpAPI usage is tracked via `SerpApiGlobalRateLimiter`. The main admin dashboard (`/admin`) should surface key AI usage metrics at a glance, similar to how we already show SerpAPI usage summaries.

- `AiUsageTracker.usage_stats` provides: monthly tokens, daily tokens, costs, projections, model breakdown
- `SerpApiGlobalRateLimiter.usage_stats` provides: monthly used/remaining, daily used/remaining, projections
- The dashboard should show a compact AI usage widget with key stats and a link to the full observability page

---

## Acceptance Criteria

- [ ] Add AI usage summary card to the main admin dashboard
- [ ] Show monthly token usage with percentage of limit
- [ ] Show monthly cost (estimated) with percentage of budget
- [ ] Show daily usage vs soft limit
- [ ] Show projected monthly total (tokens and cost)
- [ ] Visual indicator (green/yellow/red) based on usage thresholds
- [ ] Warning banner if AI processing is paused
- [ ] Link to full AI usage observability page (`/admin/observability/ai_usage`)
- [ ] Match the style/pattern of existing SerpAPI usage display on dashboard
- [ ] Tests written and passing for dashboard AI usage data
- [ ] Quality gates pass
- [ ] Changes committed with task reference

---

## Notes

- Reference: `app/services/ai_usage_tracker.rb` for data
- Reference: `app/services/serp_api_global_rate_limiter.rb` for the SerpAPI pattern to match
- Reference: `app/views/admin/observability/ai_usage.html.erb` for the detailed view
- Reference: `app/controllers/admin/dashboard_controller.rb` for adding data to dashboard
