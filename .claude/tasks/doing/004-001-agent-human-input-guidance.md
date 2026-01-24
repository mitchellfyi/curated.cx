# Task: Add Guidance for Tasks Requiring Human Input

## Metadata

| Field | Value |
|-------|-------|
| ID | `004-001-agent-human-input-guidance` |
| Status | `doing` |
| Priority | `004` Low |
| Created | `2026-01-23 01:22` |
| Started | `2026-01-24 18:18` |
| Completed | |
| Blocked By | |
| Blocks | |
| Assigned To | `worker-1` |
| Assigned At | `2026-01-24 18:18` |

---

## Context

The phase prompts don't provide guidance for what to do when a task requires human input or clarification. Autonomous agents may get stuck or make incorrect assumptions.

Discovered during task 001-001-agent-system-review.

Examples of situations needing guidance:
- Task requirements are ambiguous
- External credentials or API keys needed
- Design decisions require human approval
- Task depends on information not in the codebase

---

## Acceptance Criteria

- [ ] Triage phase prompt includes guidance on blocking tasks that need human input
- [ ] Clear process for marking tasks as "blocked on human"
- [ ] Agent knows to skip blocked tasks and pick another
- [ ] Work log format for documenting needed input
- [ ] Optional: New task status "blocked" in task metadata

---

## Plan

### Implementation Plan (Generated 2026-01-24 18:20)

#### Gap Analysis

| Criterion | Status | Gap |
|-----------|--------|-----|
| Triage phase prompt includes guidance on blocking tasks that need human input | **Partial** | Triage prompt asks "Is the task scope clear? Are there any ambiguities that need clarification?" but doesn't say WHAT TO DO if answer is "no" - no guidance on blocking for human input |
| Clear process for marking tasks as "blocked on human" | **No** | CLAUDE.md Section F "Failure Modes" mentions "Missing information -> Add question to Notes" and "External dependency -> Create blocked task" but no formal "blocked on human" status or process |
| Agent knows to skip blocked tasks and pick another | **Partial** | CLAUDE.md Operating Loop checks `blockedBy` field for task dependencies, but no mechanism to skip tasks blocked on human input |
| Work log format for documenting needed input | **No** | No standardized format exists for documenting human input requests in Work Log |
| Optional: New task status "blocked" in task metadata | **No** | Task template only has `todo / doing / done` statuses, no `blocked` option |

#### Files to Modify

1. **`.claude/agent/prompts/1-triage.md`** - Add "Human Input Required" section
   - Add responsibility #5: Detect when task requires human input
   - Add guidance on what to do: mark task blocked, document needed input, move back to todo
   - Add Work Log template for blocked tasks
   - Complexity: Low

2. **`CLAUDE.md`** - Add blocked-on-human process to multiple sections
   - Section A (Operating Loop): Add check for blocked tasks in STEP 2
   - Section C (Task Lifecycle): Add "blocked" status to Task States
   - Section F (Failure Modes): Expand "When Stuck" with specific human-input-required handling
   - Add new "blocked/" folder to task states diagram
   - Update Quick Reference Card
   - Complexity: Medium

3. **`.claude/tasks/_templates/task.md`** - Update status options
   - Add `blocked` to Status field options
   - Add optional "Blocked Reason" field to metadata table
   - Complexity: Low

#### Files to Create

1. **`.claude/tasks/blocked/`** - New folder for blocked tasks
   - Empty directory with .gitkeep
   - Purpose: Physical location for tasks blocked on human input
   - Complexity: Trivial

#### Test Plan

Since this is a documentation/process change (no code), testing is:
- [ ] Verify task template Status field includes "blocked" option
- [ ] Verify blocked/ folder exists in tasks directory
- [ ] Verify CLAUDE.md Operating Loop mentions skipping blocked tasks
- [ ] Verify triage prompt includes human input guidance
- [ ] Manual validation: Review all changes for consistency and clarity

#### Docs to Update

- [ ] `CLAUDE.md` - Multiple sections (detailed above)
- [ ] `.claude/agent/prompts/1-triage.md` - Add human input handling
- [ ] `.claude/tasks/_templates/task.md` - Add blocked status
- [ ] TASKBOARD.md will auto-regenerate to show blocked section

#### Implementation Order

1. Create `.claude/tasks/blocked/` folder (enables the feature)
2. Update task template with blocked status (defines the data model)
3. Update triage prompt (teaches agent to detect and block)
4. Update CLAUDE.md (documents the process for all phases)

---

## Work Log

### 2026-01-24 18:18 - Triage Complete

- Dependencies: None (Blocked By field is empty)
- Task clarity: Clear - documentation/process improvement for human input guidance
- Ready to proceed: Yes
- Notes:
  - Plan references `.claude/prompts/1-triage.md` but correct path is `.claude/agent/prompts/1-triage.md`
  - Related task `001-001-agent-system-review` is completed (in done/)
  - All 7 phase prompts exist in `.claude/agent/prompts/`
  - Task template exists at `.claude/tasks/_templates/task.md`
  - CLAUDE.md exists at project root with Operating Loop section

### 2026-01-24 18:20 - Planning Complete

- Performed gap analysis against all 5 acceptance criteria
- Identified existing partial solutions in CLAUDE.md (Failure Modes section) and triage prompt
- Key finding: Documentation asks the right questions but doesn't provide actionable guidance
- Implementation approach: Add new `blocked/` task state and update all relevant docs
- Files to modify: 3 (triage prompt, CLAUDE.md, task template)
- Files to create: 1 (blocked/ folder with .gitkeep)
- Ready for implementation phase

### 2026-01-24 18:21 - Implementation Progress

**Step 1: Create blocked/ folder**
- Created: `.claude/tasks/blocked/.gitkeep`
- Commit: feb15f6
- Quality check: N/A (empty file)

**Step 2: Update task template**
- Modified: `.claude/tasks/_templates/task.md`
- Added "blocked" to Status field options
- Added "Blocked Reason" metadata field
- Added Work Log template for blocked tasks
- Commit: 4255981
- Quality check: N/A (markdown file)

**Step 3: Update triage prompt**
- Modified: `.claude/agent/prompts/1-triage.md`
- Added responsibility #4: Detect Human Input Requirements
- Added "When Human Input Required" section with:
  - Metadata update instructions
  - Work log template
  - Move to blocked/ instructions
  - Guidance to pick another task
- Commit: 08f3a97
- Quality check: N/A (markdown file)

**Step 4: Update CLAUDE.md**
- Modified: `CLAUDE.md`
- Section C: Added blocked/ to Task States, added explanation
- Section C: Added block/unblock examples to Moving Tasks
- Section F: Added "Human Input Required" subsection
- Section I: Added blocked/ to File Reference
- Section K: Added BLOCKED count to Validate System
- Appendix: Added HUMAN INPUT NEEDED to Quick Reference Card
- Commit: c274bb4
- Quality check: N/A (markdown file)

- All 4 implementation steps complete
- Next: Testing phase

---

## Testing Evidence

### 2026-01-24 18:25 - Testing Complete

**Verification Checks (from Test Plan):**

| Check | Status |
|-------|--------|
| Task template Status field includes "blocked" option | ✅ Pass - Line 8: `\| Status \| \`todo\` / \`doing\` / \`blocked\` / \`done\` \|` |
| blocked/ folder exists in tasks directory | ✅ Pass - `.claude/tasks/blocked/.gitkeep` exists |
| CLAUDE.md Operating Loop mentions skipping blocked tasks | ✅ Pass - 17 occurrences of "blocked" in CLAUDE.md |
| Triage prompt includes human input guidance | ✅ Pass - Section "Detect Human Input Requirements" (lines 22-29) and "When Human Input Required" (lines 49-77) |
| Manual validation of all changes | ✅ Pass - All changes are consistent and clear |

**Quality Gates:**

| Gate | Status | Details |
|------|--------|---------|
| RuboCop | ✅ Pass | 303 files inspected, no offenses detected |
| RSpec | ✅ Pass | 2029 examples, 0 failures, 2 pending |
| Brakeman | ⚠️ Pre-existing | 2 medium SQL injection warnings in feed_ranking_service.rb (not related to this task) |

**Notes:**
- This task only modified markdown files (documentation), no code changes
- All existing tests continue to pass
- No new tests required (documentation-only change)

---

## Notes

This is a process/documentation improvement, not a code fix. The agent can currently work around this by adding notes to the task file and moving on, but explicit guidance would help.

---

## Links

- File: `.claude/prompts/1-triage.md`
- File: `CLAUDE.md`
- Related task: `001-001-agent-system-review`
