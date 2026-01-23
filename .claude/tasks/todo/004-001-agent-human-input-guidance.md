# Task: Add Guidance for Tasks Requiring Human Input

## Metadata

| Field | Value |
|-------|-------|
| ID | `004-001-agent-human-input-guidance` |
| Status | `todo` |
| Priority | `004` Low |
| Created | `2026-01-23 01:22` |
| Started | |
| Completed | |
| Blocked By | |
| Blocks | |
| Assigned To | |
| Assigned At | |

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

1. **Update triage prompt**
   - Files: `.claude/prompts/1-triage.md`
   - Actions: Add section on handling ambiguous tasks

2. **Update CLAUDE.md**
   - Files: `CLAUDE.md`
   - Actions: Add "blocked on human" process to Operating Loop

3. **Consider task status extension**
   - Files: `.claude/tasks/_templates/task.md`
   - Actions: Possibly add "blocked" status option

---

## Work Log

(To be filled during execution)

---

## Testing Evidence

(To be filled during execution)

---

## Notes

This is a process/documentation improvement, not a code fix. The agent can currently work around this by adding notes to the task file and moving on, but explicit guidance would help.

---

## Links

- File: `.claude/prompts/1-triage.md`
- File: `CLAUDE.md`
- Related task: `001-001-agent-system-review`
