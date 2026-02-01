# Task: Refactor NetworkFeedService Query Duplication

## Metadata

| Field       | Value                                   |
| ----------- | --------------------------------------- |
| ID          | `004-005-refactor-network-feed-service` |
| Status      | `todo`                                  |
| Priority    | `003` Medium                            |
| Created     | `2026-02-01 19:20`                      |
| Labels      | `technical-debt`, `refactor`            |

---

## Context

NetworkFeedService has significant code duplication (mass=152) between:
- `recent_content` method (line 26)
- `recent_notes` method (line 112)

Both methods have nearly identical structure for querying network-wide content.

Additionally, the "network sites query" pattern (finding enabled sites excluding root tenant) is repeated 6 times throughout the service.

---

## Acceptance Criteria

- [ ] Extract common network sites query to private method
- [ ] Extract common content fetching pattern
- [ ] Reduce duplication score to < 50
- [ ] Tests pass
- [ ] Quality gates pass

---

## Plan

1. **Extract base query**
   - Create `network_sites_scope` private method
   - Replace 6 occurrences

2. **Extract content pattern**
   - Create generic `recent_items` method
   - Parameterize by model class

3. **Update tests**
   - Ensure existing tests still pass

---

## Notes

- This is the highest-mass duplication in services (152)
- File: `app/services/network_feed_service.rb:26`, `app/services/network_feed_service.rb:112`

---

## Links

- Related: `app/services/network_feed_service.rb`
