# Task: Validate Prompt Files Exist Before Execution

## Metadata

| Field | Value |
|-------|-------|
| ID | `003-002-agent-prompt-validation` |
| Status | `todo` |
| Priority | `003` Medium |
| Created | `2026-01-23 01:21` |
| Started | |
| Completed | |
| Blocked By | |
| Blocks | |
| Assigned To | |
| Assigned At | |

---

## Context

The agent (`bin/agent`) does not validate that all prompt files exist during startup health checks. If a prompt file is missing (e.g., `.claude/prompts/3-implement.md`), the phase will fail at runtime rather than during startup.

Discovered during task 001-001-agent-system-review.

Early validation provides better user experience and faster failure.

---

## Acceptance Criteria

- [ ] Health check validates all 7 prompt files exist
- [ ] Clear error message if any prompt file is missing
- [ ] Agent exits cleanly if validation fails
- [ ] Only validates prompts that will be used (respect SKIP_* flags)
- [ ] shellcheck passes on bin/agent

---

## Plan

1. **Add validation function**
   - Files: `bin/agent`
   - Actions: Create `validate_prompts()` function

2. **Integrate into health check**
   - Files: `bin/agent`
   - Actions: Add call to `validate_prompts()` in `run_health_checks()`

3. **Test validation**
   - Commands: Move a prompt file, run agent, verify error
   - Restore prompt file after test

---

## Work Log

(To be filled during execution)

---

## Testing Evidence

(To be filled during execution)

---

## Notes

Current prompt files (all 7 required):
- `.claude/prompts/1-triage.md`
- `.claude/prompts/2-plan.md`
- `.claude/prompts/3-implement.md`
- `.claude/prompts/4-test.md`
- `.claude/prompts/5-docs.md`
- `.claude/prompts/6-review.md`
- `.claude/prompts/7-verify.md`

---

## Links

- File: `bin/agent`
- Dir: `.claude/prompts/`
- Related task: `001-001-agent-system-review`
