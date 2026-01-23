# Task: Review and Improve Agent System

## Metadata

| Field | Value |
|-------|-------|
| ID | `001-001-agent-system-review` |
| Status | `todo` |
| Priority | `001` Critical |
| Created | `2026-01-23 00:50` |
| Started | |
| Completed | |
| Blocked By | |
| Blocks | |
| Assigned To | |
| Assigned At | |

---

## Context

The autonomous agent system (`bin/agent`) was recently created and has undergone several iterations of fixes. A comprehensive review is needed to ensure reliability, identify edge cases, and improve the overall design.

Key areas to review:
- Phase execution workflow
- Error handling and recovery
- Lock management for parallel agents
- Session persistence and resume
- Prompt templates effectiveness

---

## Acceptance Criteria

All must be checked before moving to done:

- [ ] Review all 7 phase prompt templates for clarity and effectiveness
- [ ] Test parallel agent execution (2-3 agents simultaneously)
- [ ] Test crash recovery (kill agent mid-task, verify resume)
- [ ] Test lock timeout/stale detection
- [ ] Verify heartbeat refresh works correctly
- [ ] Test all SKIP_* and TIMEOUT_* environment variables
- [ ] Review error messages for user-friendliness
- [ ] Document any edge cases found
- [ ] Create follow-up tasks for improvements discovered
- [ ] Quality gates pass (shellcheck, bash -n)

---

## Plan

Step-by-step implementation approach:

1. **Code Review**: Thorough review of `bin/agent`
   - Files: `bin/agent`
   - Actions: Read through entire script, identify potential issues

2. **Prompt Review**: Review all phase prompts
   - Files: `.claude/prompts/1-triage.md` through `7-verify.md`
   - Actions: Ensure prompts are clear, complete, non-overlapping

3. **Parallel Testing**: Test multiple agents
   - Actions: Run `./bin/agent 3 &` multiple times, verify no conflicts

4. **Crash Recovery Testing**: Test resume functionality
   - Actions: Start agent, kill mid-task, restart, verify resume

5. **Edge Case Documentation**: Document findings
   - Files: `docs/agent-system.md` (create if needed)
   - Actions: Document edge cases, gotchas, recommendations

6. **Create Follow-up Tasks**: For any improvements
   - Files: `.claude/tasks/todo/`
   - Actions: Create tasks for non-critical improvements

---

## Work Log

(To be filled during execution)

---

## Testing Evidence

(To be filled during execution)

---

## Notes

Recent fixes made:
- Session file quoting (timestamp with spaces)
- Bash 3.2 compatibility (${var,,} syntax)
- Phase-level retry logic
- VERIFY phase addition
- Auto-generated worker names

---

## Links

- File: `bin/agent`
- Files: `.claude/prompts/*.md`
- File: `CLAUDE.md` (agent documentation)
