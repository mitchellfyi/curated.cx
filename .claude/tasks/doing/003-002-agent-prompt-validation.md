# Task: Validate Prompt Files Exist Before Execution

## Metadata

| Field | Value |
|-------|-------|
| ID | `003-002-agent-prompt-validation` |
| Status | `doing` |
| Priority | `003` Medium |
| Created | `2026-01-23 01:21` |
| Started | `2026-01-24 17:15` |
| Completed | |
| Blocked By | |
| Blocks | |
| Assigned To | `worker-1` |
| Assigned At | `2026-01-24 17:15` |

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

### Implementation Plan (Generated 2026-01-24 17:17)

#### Gap Analysis
| Criterion | Status | Gap |
|-----------|--------|-----|
| Health check validates all 7 prompt files exist | No | No validation exists - `build_phase_prompt()` checks at runtime (line 617-621) but `health_check()` (lines 898-967) doesn't validate prompts |
| Clear error message if any prompt file is missing | No | Current runtime error at line 620 is generic "Prompt file not found" - need improved messaging listing which prompts are missing |
| Agent exits cleanly if validation fails | Partial | `health_check()` returns 1 on failure and `main()` exits (line 1366-1369), but prompt validation not integrated |
| Only validates prompts that will be used (respect SKIP_* flags) | No | Need to check SKIP_TRIAGE, SKIP_PLAN, etc. and only validate non-skipped phase prompts |
| shellcheck passes on bin/agent | Unknown | Need to verify - `bin/agent` is a wrapper at `/Users/mitchell/Dropbox/work/Personal/curated.www/bin/agent` |

#### Files to Modify
1. `.claude/agent/lib/core.sh` (lines 898-967)
   - Add `validate_prompts()` function before `health_check()`
   - Function should:
     - Iterate through PHASES array (lines 89-97)
     - For each phase, check if SKIP_* flag is set
     - If not skipped, verify prompt file exists at `$PROMPTS_DIR/$prompt_file`
     - Collect all missing prompts
     - Return error with clear message listing all missing files
   - Call `validate_prompts` within `health_check()` after disk space check (around line 951)

2. `bin/agent` (wrapper script)
   - May need shellcheck fixes if any issues found
   - Likely minimal - it just sources/calls core.sh

#### Files to Create
None needed.

#### Implementation Details

**validate_prompts() function** (insert around line 895, before health_check):
```bash
validate_prompts() {
  local missing=()

  for phase_def in "${PHASES[@]}"; do
    IFS='|' read -r name prompt_file timeout skip <<< "$phase_def"

    # Skip if this phase is disabled
    if [ "$skip" = "1" ]; then
      continue
    fi

    # Check if prompt file exists
    local prompt_path="$PROMPTS_DIR/$prompt_file"
    if [ ! -f "$prompt_path" ]; then
      missing+=("$prompt_file (phase: $name)")
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    log_error "Missing prompt files:"
    for m in "${missing[@]}"; do
      echo "  - $m"
    done
    echo "  Expected location: $PROMPTS_DIR/"
    return 1
  fi

  return 0
}
```

**Integration into health_check()** (around line 951, after disk space check):
```bash
# Validate prompt files
if ! validate_prompts; then
  ((issues++))
else
  log_success "Prompt files OK (non-skipped phases)"
fi
```

#### Test Plan
- [ ] Run `shellcheck bin/agent` - should pass
- [ ] Run `shellcheck .claude/agent/lib/core.sh` - should pass (or document acceptable warnings)
- [ ] Test with all prompts present: `./bin/agent 1` should pass health check
- [ ] Test with missing prompt: `mv .claude/agent/prompts/3-implement.md /tmp/ && AGENT_DRY_RUN=1 ./bin/agent 1` - should fail with clear error
- [ ] Test with skipped phase: `mv .claude/agent/prompts/3-implement.md /tmp/ && SKIP_IMPLEMENT=1 AGENT_DRY_RUN=1 ./bin/agent 1` - should pass (prompt not needed)
- [ ] Restore prompt file after testing

#### Docs to Update
- [ ] None required - feature is self-documenting via error messages

---

## Work Log

### 2026-01-24 17:15 - Triage Complete

- **Dependencies:** None (Blocked By field is empty). Related task `001-001-agent-system-review` is completed.
- **Task clarity:** Clear. Corrected path references in Notes section (was `.claude/prompts/`, actual is `.claude/agent/prompts/`).
- **Ready to proceed:** Yes
- **Notes:**
  - All 7 prompt files exist at `.claude/agent/prompts/`
  - The core implementation is in `.claude/agent/lib/core.sh`, not `bin/agent` (which is just a wrapper)
  - The `health_check()` function (lines 898-967) currently validates CLI, CLAUDE.md, directories, locks, disk space - but not prompt files
  - The `build_phase_prompt()` function checks prompts at runtime but doesn't fail early during startup
  - Need to add `validate_prompts()` function and integrate into `health_check()`
  - Must respect SKIP_* flags to only validate prompts that will actually be used

### 2026-01-24 17:17 - Planning Complete

- **Gap analysis:** Completed full gap analysis against acceptance criteria
- **Key findings:**
  - No prompt validation currently exists at startup
  - PHASES array at lines 89-97 defines all phases with `name|prompt_file|timeout|skip` format
  - `health_check()` at lines 898-967 is the natural integration point
  - SKIP_* flags are evaluated at runtime via phase definitions, can be checked during validation
- **Implementation approach:**
  - Add `validate_prompts()` function before `health_check()` (~line 895)
  - Iterate PHASES array, skip phases where skip=1, check others for prompt file existence
  - Collect all missing files and display clear error with expected path
  - Call from `health_check()` after disk space check
- **Files to modify:** `.claude/agent/lib/core.sh` only
- **Estimated changes:** ~25 lines of bash code
- **Ready for implementation:** Yes

### 2026-01-24 17:18 - Implementation Progress

- **Completed:** Added `validate_prompts()` function and integrated into `health_check()`
- **Files modified:** `.claude/agent/lib/core.sh`
- **Commit:** b3b56f7
- **Quality check:** shellcheck passes on both `bin/agent` and `.claude/agent/lib/core.sh`
- **Changes:**
  - Added `validate_prompts()` function (lines 894-928) that:
    - Iterates through PHASES array
    - Skips phases where skip=1 (respects SKIP_* flags)
    - Collects all missing prompt files
    - Returns error with clear message listing all missing files and expected location
  - Integrated call in `health_check()` (lines 989-994) after disk space check
  - Total: 43 lines added
- **Next:** Testing phase (verify all acceptance criteria met)

---

## Testing Evidence

(To be filled during testing phase)

---

## Notes

Current prompt files (all 7 required, located at `.claude/agent/prompts/`):
- `.claude/agent/prompts/1-triage.md`
- `.claude/agent/prompts/2-plan.md`
- `.claude/agent/prompts/3-implement.md`
- `.claude/agent/prompts/4-test.md`
- `.claude/agent/prompts/5-docs.md`
- `.claude/agent/prompts/6-review.md`
- `.claude/agent/prompts/7-verify.md`

Note: The core agent script is at `.claude/agent/lib/core.sh` (not `bin/agent` which is just a wrapper).
The `PROMPTS_DIR` variable is set to `$AGENT_DIR/prompts` which resolves to `.claude/agent/prompts/`.

---

## Links

- File: `.claude/agent/lib/core.sh` (main implementation)
- File: `bin/agent` (wrapper script)
- Dir: `.claude/agent/prompts/`
- Related task: `001-001-agent-system-review`
