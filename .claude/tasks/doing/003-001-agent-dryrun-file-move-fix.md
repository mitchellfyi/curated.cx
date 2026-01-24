# Task: Fix DRY RUN Mode Moving Task Files

## Metadata

| Field | Value |
|-------|-------|
| ID | `003-001-agent-dryrun-file-move-fix` |
| Status | `doing` |
| Priority | `003` Medium |
| Created | `2026-01-23 01:20` |
| Started | `2026-01-24 16:59` |
| Completed | |
| Blocked By | |
| Blocks | |
| Assigned To | `worker-1` |
| Assigned At | `2026-01-24 16:59` |

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

### Implementation Plan (Generated 2026-01-24 17:15)

#### Gap Analysis
| Criterion | Status | Gap |
|-----------|--------|-----|
| DRY_RUN=1 does not move task files | NO | Lines 1163-1165 move files BEFORE dry-run check at line 1175 |
| DRY_RUN=1 does not create/modify lock files | NO | Line 1155 acquires lock BEFORE dry-run check at line 1175 |
| DRY_RUN=1 shows accurate preview | PARTIAL | Shows phases but not which task would be selected |
| DRY_RUN=1 validates task selection logic | PARTIAL | Task selection runs but file ops shouldn't happen |
| Tests or manual verification documented | NO | No tests exist, manual verification needed |
| shellcheck passes on bin/agent | UNKNOWN | Need to verify |

#### Root Cause
In `.claude/agent/lib/core.sh`, the `run_agent_iteration()` function (lines 1120-1241):
1. Lines 1143-1172: Finds task, acquires lock, moves file, assigns task, commits
2. Line 1175: **Only then** checks `AGENT_DRY_RUN` and skips phases

The dry-run check happens **after** all the file operations.

#### Files to Modify
1. `.claude/agent/lib/core.sh` - Refactor `run_agent_iteration()` function:
   - Move dry-run check to BEFORE file operations (after task selection, before lock/move/assign)
   - Add enhanced dry-run output showing what task WOULD be picked
   - Ensure no file system changes happen in dry-run mode except logs

#### Specific Changes
1. **In `run_agent_iteration()` (around line 1140)**:
   - After finding `task_file` but BEFORE acquiring lock
   - Add dry-run check: if `AGENT_DRY_RUN=1`, log what would happen and return early
   - Show: task that would be picked, phases that would run
   - Do NOT: acquire lock, move file, assign task, commit

2. **Improve dry-run output**:
   - Show which task would be selected from todo/
   - Show which phases would run (considering SKIP_* flags)
   - Show model that would be used
   - Make it clear no files were changed

#### Files to Create
None needed.

#### Test Plan
Manual verification steps (to document in Testing Evidence):
- [ ] Create a test task in todo/
- [ ] Run `AGENT_DRY_RUN=1 ./bin/agent 1`
- [ ] Verify task remains in todo/ (not moved to doing/)
- [ ] Verify no .lock files created in .claude/locks/
- [ ] Verify accurate preview output shows which task would be selected
- [ ] Verify task assignment metadata NOT updated
- [ ] Run `shellcheck bin/agent` and `.claude/agent/lib/core.sh` - ensure no errors

#### Docs to Update
- [ ] `.claude/tasks/doing/003-001-agent-dryrun-file-move-fix.md` - Update Work Log with testing evidence

---

## Work Log

### 2026-01-24 17:20 - Implementation Complete

- Completed: Moved dry-run check BEFORE file operations in `run_agent_iteration()`
- Files modified: `.claude/agent/lib/core.sh`
- Commit: 8fd97ca
- Quality check: shellcheck passes on both `bin/agent` and `.claude/agent/lib/core.sh`
- Changes:
  1. Added dry-run check when no tasks available (lines 1144-1149)
  2. Added dry-run check when resuming task in doing/ (lines 1159-1168)
  3. Added dry-run check BEFORE file ops when picking new task (lines 1170-1184)
  4. Removed old dry-run check that happened AFTER file operations
- Enhanced dry-run output now shows:
  - Which task would be selected
  - What file operations would occur (move, lock, assign)
  - Which phases would run
  - Current model configuration
- Next: Test phase (manual verification)

### 2026-01-24 17:15 - Planning Complete

- Analyzed `.claude/agent/lib/core.sh` (1423 lines)
- Found root cause in `run_agent_iteration()` function (lines 1120-1241)
- Issue: Dry-run check at line 1175 happens AFTER file operations (lines 1143-1172)
- Solution: Move dry-run check earlier, before lock acquisition and file move
- Single file to modify: `.claude/agent/lib/core.sh`
- No tests exist - will use manual verification
- Created detailed implementation plan with specific line numbers

### 2026-01-24 16:59 - Triage Complete

- Dependencies: None (Blocked By field is empty)
- Task clarity: Clear - well-defined problem and acceptance criteria
- Ready to proceed: Yes
- Notes:
  - Related task 001-001-agent-system-review is complete in done/
  - bin/agent file exists and is ready for modification
  - Problem clearly described: dry-run moves files before checking the flag
  - All 6 acceptance criteria are specific and testable

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
