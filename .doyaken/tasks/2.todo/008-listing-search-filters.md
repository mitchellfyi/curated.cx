# Advanced Listing Search & Filters

## Description

Add search and filtering capabilities to the listings pages so users can find relevant tools, jobs, and services quickly.

## Acceptance Criteria

- [ ] Add search input on listings index page
- [ ] Filter by category (dropdown or tabs)
- [ ] Filter by listing type (tool, job, service, event)
- [ ] Filter by freshness (today, this week, this month)
- [ ] URL params for shareable filtered views
- [ ] Mobile-friendly filter UI
- [ ] Loading states for filter changes

## Technical Approach

1. Add Stimulus controller for filter interactions
2. Use Turbo Frames for AJAX filtering
3. Add query scopes to Listing model
4. Update listings controller to handle filters

## Priority

high

## Labels

feature, ux
