# Task: Fix All Observability Pages and Add Request Tests

## Metadata

| Field       | Value                                                  |
| ----------- | ------------------------------------------------------ |
| ID          | `013-fix-observability-pages-add-request-tests`        |
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

The observability section has 5 pages (overview, imports, editorialisations, serp_api, ai_usage) that need to be verified working correctly and covered by request specs. These pages aggregate data from multiple models and services, and any breakage could go unnoticed without proper test coverage.

- Overview: `/admin/observability` - aggregates stats from imports, editorialisations, content, jobs, SerpAPI, AI, workflow pauses
- Imports: `/admin/observability/imports` - import pipeline stats and list
- Editorialisations: `/admin/observability/editorialisations` - AI processing stats and list
- SerpAPI: `/admin/observability/serp_api` - SerpAPI usage tracking with charts
- AI Usage: `/admin/observability/ai_usage` - AI cost/token tracking with charts

---

## Acceptance Criteria

- [ ] Verify each observability page loads without errors (all 5 pages)
- [ ] Fix any N+1 queries in observability controller
- [ ] Fix any nil/missing data handling (pages should work with empty data)
- [ ] Fix any broken view rendering (partials, helpers, chart data)
- [ ] Ensure stats calculations are correct in services (`AiUsageTracker`, `SerpApiGlobalRateLimiter`)
- [ ] Add request spec: `GET /admin/observability` returns 200 with expected content
- [ ] Add request spec: `GET /admin/observability/imports` returns 200
- [ ] Add request spec: `GET /admin/observability/editorialisations` returns 200
- [ ] Add request spec: `GET /admin/observability/serp_api` returns 200
- [ ] Add request spec: `GET /admin/observability/ai_usage` returns 200
- [ ] Test pages with empty data (no imports, no editorialisations, etc.)
- [ ] Test pages with sample data to verify stats rendering
- [ ] Test authorization (admin required, non-admin rejected)
- [ ] All tests passing
- [ ] Quality gates pass
- [ ] Changes committed with task reference

---

## Notes

- Reference: `app/controllers/admin/observability_controller.rb`
- Reference: `app/views/admin/observability/`
- Reference: `app/services/ai_usage_tracker.rb`, `app/services/serp_api_global_rate_limiter.rb`
- Spec file: `spec/requests/admin/observability_spec.rb` (create if doesn't exist)
- Use factory_bot factories for test data setup
