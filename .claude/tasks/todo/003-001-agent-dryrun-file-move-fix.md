# Task: Fix DRY RUN Mode Moving Task Files

## Metadata

| Field | Value |
|-------|-------|
| ID | `003-001-agent-dryrun-file-move-fix` |
| Status | `todo` |
| Priority | `003` Medium |
| Created | `2026-01-23 01:20` |
| Started | |
| Completed | |
| Blocked By | |
| Blocks | |
| Assigned To | |
| Assigned At | |

---

## Context

When running `AGENT_DRY_RUN=1 ./bin/agent`, the agent still moves task files from `todo/` to `doing/` before checking the dry-run flag. This can leave tasks stranded in `doing/` when testing.

Discovered during task 001-001-agent-system-review.

Expected behavior: In dry-run mode, no file system changes should occur (except logs).

---

## Acceptance Criteria

- [ ] DRY_RUN=1 does not move task files from todo/ to doing/
- [ ] DRY_RUN=1 does not create or modify lock files
- [ ] DRY_RUN=1 still shows accurate preview of what would happen
- [ ] DRY_RUN=1 still validates task selection logic
- [ ] Tests or manual verification documented
- [ ] shellcheck passes on bin/agent

---

## Plan

1. **Locate the issue**
   - Files: `bin/agent`
   - Actions: Find where task files are moved and where dry-run check happens

2. **Refactor task selection**
   - Files: `bin/agent`
   - Actions: Move dry-run check earlier, before file operations

3. **Test the fix**
   - Commands: `AGENT_DRY_RUN=1 ./bin/agent 1`
   - Verify: No files in doing/, no locks created

---

## Work Log

(To be filled during execution)

---

## Testing Evidence

(To be filled during execution)

---

## Notes

Current behavior (from testing):
- Agent picks task from todo/
- Moves file to doing/
- Acquires lock
- Then checks DRY_RUN and skips phases
- On exit, releases lock and clears assignment
- But file remains in doing/

---

## Links

- File: `bin/agent`
- Related task: `001-001-agent-system-review`
- Doc: `docs/agent-system.md`
