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

### 2026-01-24 17:09 - Documentation Sync

Docs updated:
- docs/agent-system.md - Rewrote "DRY RUN Mode" section (was "DRY RUN Moves Task Files")
  - Changed from describing it as a known limitation/bug
  - Now documents the correct behavior with example output
  - Updated testing checklist to verify no file changes in dry-run mode

Annotations:
- Models annotated: No changes needed (bundle exec annotaterb models - unchanged)

Consistency checks:
- [x] Code matches docs - DRY_RUN behavior now documented correctly
- [x] No broken links - All links in task file valid
- [x] Schema annotations current - No model changes in this task

Notes section updated:
- Added "Fixed behavior" description
- Renamed old behavior as "Previous behavior (now fixed)"

Links section updated:
- Added implementation file reference with line numbers
- Added doc update note

### 2026-01-24 17:07 - Testing Complete

Tests executed:
- Manual verification of dry-run behavior - 5 tests
- All tests PASS

Test results:
- Test 1: Dry-run does not move task files ✅
- Test 2: Task assignment metadata not modified ✅
- Test 3: Accurate preview output ✅
- Test 4: Shellcheck passes ✅
- Test 5: Full quality suite passes ✅

Quality gates:
- RuboCop: PASS (291 files, no offenses)
- ERB Lint: PASS (83 files, no errors)
- Brakeman: PASS (no security warnings)
- Bundle Audit: PASS (no vulnerabilities)
- RSpec: PASS (all tests passing)
- Shellcheck: PASS (no errors)

All acceptance criteria verified - ready for docs and review phases.

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

### Manual Verification (2026-01-24 17:07)

#### Test 1: Dry-run does not move task files

**Setup:** Created test task `999-999-dry-run-test-task.md` in todo/

**Before dry-run:**
```
Tasks in todo/: 4 files (including test task)
Tasks in doing/: 1 file (003-001-agent-dryrun-file-move-fix.md)
Lock files: 3 locks
```

**Command:** `AGENT_DRY_RUN=1 ./bin/agent 1`

**Output shows:**
```
[worker-2 WARN] DRY RUN - would pick up task: 003-002-agent-prompt-validation
[worker-2] Task file: .../todo/003-002-agent-prompt-validation.md
[worker-2] Would move: todo/ → doing/
[worker-2] Would acquire lock: .../003-002-agent-prompt-validation.lock
[worker-2] Would assign to: worker-2
[worker-2] Phases: TRIAGE|...|VERIFY
[worker-2] Model: opus
[worker-2] No file changes made
```

**After dry-run:**
```
Tasks in todo/: 4 files (unchanged - test task still there)
Tasks in doing/: 1 file (unchanged)
Lock files: 3 locks (no new lock created)
```

**Result:** ✅ PASS - Task NOT moved, no lock created

#### Test 2: Task assignment metadata not modified

**Command:** `grep -A1 "Assigned To" .claude/tasks/todo/003-002-agent-prompt-validation.md`

**Output:**
```
| Assigned To | |
| Assigned At | |
```

**Result:** ✅ PASS - Assignment fields remain empty

#### Test 3: Accurate preview output

**Verified the dry-run output shows:**
- ✅ Which task would be selected (003-002-agent-prompt-validation)
- ✅ What file operations would occur (move, lock, assign)
- ✅ Which phases would run (all 7 phases listed)
- ✅ Model configuration (opus)
- ✅ Clear message "No file changes made"

**Result:** ✅ PASS - Preview output is accurate and informative

#### Test 4: Shellcheck passes

**Command:** `shellcheck bin/agent .claude/agent/lib/core.sh`

**Output:** No errors or warnings

**Result:** ✅ PASS

#### Test 5: Full quality suite

**Command:** `./bin/quality`

**Output:**
```
🎉 All critical quality checks passed!

📊 Quality Summary:
   ✅ Code style compliance (RuboCop + SOLID principles)
   ✅ Security vulnerability scan (Brakeman)
   ✅ Dependency security check (Bundle Audit)
   ✅ Test suite with coverage (RSpec + Test Pyramid)
   ✅ Route testing coverage (All routes tested)
   ✅ Internationalization compliance (i18n-tasks)
   ✅ SEO optimization (Meta tags, structured data, sitemaps)
   ✅ Accessibility compliance (WCAG 2.1 AA)
   ✅ Database schema validation
   ✅ Multi-tenant isolation verification
```

**Result:** ✅ PASS - All critical gates pass

#### Cleanup

- Deleted test task: `rm -f .claude/tasks/todo/999-999-dry-run-test-task.md`

---

## Notes

**Fixed behavior (after implementation):**
- Agent checks DRY_RUN flag BEFORE any file operations
- In dry-run mode, shows preview of what would happen
- No file moves, no lock acquisition, no assignment metadata changes
- Clear "No file changes made" message in output

**Previous behavior (now fixed):**
- Agent picked task from todo/
- Moved file to doing/
- Acquired lock
- Then checked DRY_RUN and skipped phases
- On exit, released lock and cleared assignment
- But file remained in doing/

---

## Links

- File: `bin/agent`
- Implementation: `.claude/agent/lib/core.sh` (lines 1144-1184)
- Related task: `001-001-agent-system-review`
- Doc: `docs/agent-system.md` (updated section 1 - DRY RUN Mode)
