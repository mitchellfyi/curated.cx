# Task: Update Outdated Dependencies

## Metadata

| Field       | Value                         |
| ----------- | ----------------------------- |
| ID          | `004-006-update-outdated-gems`|
| Status      | `todo`                        |
| Priority    | `002` High                    |
| Created     | `2026-02-01 19:20`            |
| Labels      | `technical-debt`, `deps`      |

---

## Context

Several gems are outdated with significant version gaps:

**High Priority (security/major versions):**
- `stripe`: 13.5.1 → 18.3.0 (major version gap)
- `mux_ruby`: 3.20.0 → 5.1.0 (major version gap)
- `brakeman`: 7.1.2 → 8.0.1

**Medium Priority:**
- `rubocop`: 1.80.2 → 1.84.0
- `rubycritic`: 4.12.0 → 5.0.0
- `nokogiri`: 1.18.10 → 1.19.0
- `faraday-*` suite (multiple packages)

**Low Priority:**
- Various minor version updates

---

## Acceptance Criteria

- [ ] Update high priority gems with breaking change review
- [ ] Update medium priority gems
- [ ] Run full test suite after each update
- [ ] Quality gates pass
- [ ] No security vulnerabilities introduced

---

## Plan

1. **Stripe update (careful)**
   - Review changelog for breaking changes
   - Update incrementally if needed
   - Run Stripe-related tests

2. **Mux update (careful)**
   - Review changelog for breaking changes
   - Update and test streaming features

3. **Security/lint tools**
   - Update brakeman, rubocop
   - Run quality checks

4. **Other updates**
   - Bundle update for remaining gems
   - Full test suite

---

## Notes

- Stripe 18.x may have significant API changes
- Run `bundle outdated` to get current list
- npm shows only minor update: `@hotwired/turbo-rails` 8.0.21 → 8.0.23

---

## Links

- Stripe changelog: https://github.com/stripe/stripe-ruby/blob/master/CHANGELOG.md
- Mux changelog: https://github.com/muxinc/mux-ruby/releases
