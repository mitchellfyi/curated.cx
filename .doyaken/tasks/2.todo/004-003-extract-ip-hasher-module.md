# Task: Extract IP Hashing Module

## Metadata

| Field       | Value                           |
| ----------- | ------------------------------- |
| ID          | `004-003-extract-ip-hasher`     |
| Status      | `todo`                          |
| Priority    | `003` Medium                    |
| Created     | `2026-02-01 19:20`              |
| Labels      | `technical-debt`, `refactor`    |

---

## Context

Identical `hash_ip` method found in multiple services:
- `BoostAttributionService` line 87
- `NetworkBoostService` line 85

Both contain the exact same IP hashing implementation. Flay identified this as mass*2=72 (identical).

---

## Acceptance Criteria

- [ ] Create shared module for IP hashing
- [ ] Refactor `BoostAttributionService` to use module
- [ ] Refactor `NetworkBoostService` to use module
- [ ] Tests pass
- [ ] Quality gates pass

---

## Plan

1. **Create module**: `app/services/concerns/ip_hashable.rb`
   - Extract `hash_ip` method
   - Make it a class method or mixin

2. **Refactor services**
   - Include module in both services
   - Remove duplicate methods

3. **Update tests**
   - Ensure existing tests still pass

---

## Notes

- This is a quick win - small change, eliminates identical code
- Files: `app/services/boost_attribution_service.rb:87`, `app/services/network_boost_service.rb:85`

---

## Links

- Related: `app/services/boost_attribution_service.rb`
- Related: `app/services/network_boost_service.rb`
