# Agent System Documentation

The autonomous agent system (`bin/agent`) enables Claude to work independently on tasks
with self-healing, crash recovery, and parallel execution support.

## Quick Reference

```bash
# Basic usage
./bin/agent          # Run 5 tasks
./bin/agent 3        # Run 3 tasks

# Parallel agents
./bin/agent 5 &
./bin/agent 5 &
./bin/agent 5 &

# With options
AGENT_DRY_RUN=1 ./bin/agent 1     # Preview without executing
AGENT_QUIET=1 ./bin/agent 3       # Minimal output
SKIP_DOCS=1 ./bin/agent 1         # Skip documentation phase
```

## Architecture

### Phase-Based Execution

Each task goes through 7 distinct phases, each with a fresh Claude session:

| Phase | Timeout | Purpose |
|-------|---------|---------|
| 1. TRIAGE | 2min | Validate task, check dependencies |
| 2. PLAN | 5min | Gap analysis, implementation planning |
| 3. IMPLEMENT | 30min | Execute the plan, write code |
| 4. TEST | 10min | Run tests, add coverage |
| 5. DOCS | 5min | Sync documentation |
| 6. REVIEW | 5min | Code review, create follow-ups |
| 7. VERIFY | 2min | Verify task is truly complete |

### Lock Management

The system uses file-based locks to prevent conflicts:

- Lock file: `.claude/locks/<task-id>.lock`
- Format: Shell variable file with AGENT_ID, LOCKED_AT, PID, TASK_ID
- Atomic acquisition: Uses `mkdir` for race-safe locking
- Stale detection: Dead PID or age > AGENT_LOCK_TIMEOUT

### Session State

State is persisted to `.claude/state/` for crash recovery:
- `<agent-id>-iter<n>.session` - Current iteration info
- Auto-resumed on next run (unless AGENT_NO_RESUME=1)

## Environment Variables

### Core Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `CLAUDE_MODEL` | `opus` | Primary model (opus, sonnet, haiku) |
| `AGENT_NAME` | auto | Agent identifier (auto: worker-1, worker-2...) |
| `AGENT_DRY_RUN` | `0` | Preview mode - no execution |
| `AGENT_QUIET` | `0` | Disable streaming output |
| `AGENT_VERBOSE` | `0` | Enable verbose output |

### Retry & Recovery

| Variable | Default | Description |
|----------|---------|-------------|
| `AGENT_MAX_RETRIES` | `2` | Retries per phase |
| `AGENT_RETRY_DELAY` | `5` | Base delay (exponential backoff) |
| `AGENT_NO_RESUME` | `0` | Skip session resume |
| `AGENT_NO_FALLBACK` | `0` | Disable model fallback |

### Locks & Timeouts

| Variable | Default | Description |
|----------|---------|-------------|
| `AGENT_LOCK_TIMEOUT` | `10800` | Stale lock threshold (3 hours) |
| `AGENT_HEARTBEAT` | `3600` | Assignment refresh interval (1 hour) |

### Phase Skipping

Set any of these to `1` to skip that phase:

- `SKIP_TRIAGE` - Skip task validation
- `SKIP_PLAN` - Skip planning
- `SKIP_IMPLEMENT` - Skip implementation
- `SKIP_TEST` - Skip testing
- `SKIP_DOCS` - Skip documentation
- `SKIP_REVIEW` - Skip review
- `SKIP_VERIFY` - Skip verification

### Phase Timeouts

Override default timeouts (in seconds):

- `TIMEOUT_TRIAGE` (default: 120)
- `TIMEOUT_PLAN` (default: 300)
- `TIMEOUT_IMPLEMENT` (default: 1800)
- `TIMEOUT_TEST` (default: 600)
- `TIMEOUT_DOCS` (default: 300)
- `TIMEOUT_REVIEW` (default: 300)
- `TIMEOUT_VERIFY` (default: 120)

## Edge Cases & Gotchas

### 1. DRY RUN Moves Task Files

**Issue**: `AGENT_DRY_RUN=1` still moves tasks from `todo/` to `doing/` before the dry-run check.

**Impact**: Running multiple dry runs can leave tasks stranded in `doing/`.

**Workaround**: After dry-run testing, move tasks back:
```bash
mv .claude/tasks/doing/*.md .claude/tasks/todo/
```

**Status**: Known limitation - dry-run primarily tests lock acquisition and phase configuration.

### 2. Dead Process Lock Detection

**Behavior**: Locks with non-running PIDs are automatically detected as stale and removed.

**How it works**:
1. Agent reads PID from lock file
2. Checks `kill -0 $pid` to see if process exists
3. If process dead, removes lock and claims task

**Tested**: Works correctly - agent logs "Lock PID X is not running - lock is stale"

### 3. Age-Based Stale Detection

**Behavior**: Locks older than `AGENT_LOCK_TIMEOUT` (default 3 hours) are considered stale.

**Use case**: Process is running but stuck/hung. After 3 hours, another agent can claim the task.

**Override**: Set `AGENT_LOCK_TIMEOUT=N` for shorter/longer threshold (in seconds).

### 4. Heartbeat for Long Tasks

**Behavior**: Long-running tasks refresh their assignment timestamp every `AGENT_HEARTBEAT` seconds.

**Purpose**: Prevents tasks from being marked stale while actively being worked on.

**Note**: Heartbeat only updates the task file's `Assigned At` field, not the lock file.

### 5. Multiple Phases Skip Interaction

**Safe to combine**: Any SKIP_* variables can be combined.

Example:
```bash
SKIP_TRIAGE=1 SKIP_DOCS=1 SKIP_REVIEW=1 ./bin/agent 1
```

**Caveat**: Skipping VERIFY phase means task completion isn't validated.

### 6. Model Fallback on Rate Limits

**Behavior**: If opus hits rate limits, automatically falls back to sonnet.

**Control**: Set `AGENT_NO_FALLBACK=1` to fail instead of falling back.

**Log indicator**: Look for "Falling back to sonnet" in logs.

### 7. Circuit Breaker

**Behavior**: After 3 consecutive phase failures, pauses 30 seconds.

**Purpose**: Avoid hammering API during transient issues.

**Log indicator**: "Circuit breaker triggered"

### 8. QUIET Mode vs VERBOSE Mode

- `AGENT_QUIET=1` - Disables streaming, shows only summary
- `AGENT_VERBOSE=1` - Shows all debug output

These are mutually exclusive - if both set, VERBOSE takes precedence.

### 9. Session Resume After Crash

**Behavior**: Interrupted sessions are automatically resumed.

**Detection**: Looks for session files in `.claude/state/`

**Disable**: Set `AGENT_NO_RESUME=1` to start fresh.

**Note**: Resume only works within same iteration - task state is preserved in task file.

### 10. Worker Name Collision

**Behavior**: Auto-generated worker names (worker-1, worker-2) check for active workers.

**Detection**: Uses `.claude/locks/.worker-N.active/` directories.

**Edge case**: If process dies without cleanup, directory persists until timeout.

**Fix**: Clean up manually:
```bash
rm -rf .claude/locks/.worker-*.active
```

## Troubleshooting

### Tasks Stuck in doing/

```bash
# Check what's in doing
ls .claude/tasks/doing/

# Check locks for those tasks
ls .claude/locks/*.lock

# If agent is dead, move back to todo
mv .claude/tasks/doing/*.md .claude/tasks/todo/
rm -f .claude/locks/*.lock
```

### Stale Worker Markers

```bash
# List active worker markers
ls -la .claude/locks/.worker-*.active/

# Remove stale ones (when agents not running)
rm -rf .claude/locks/.worker-*.active/
```

### Clear All State

```bash
# Nuclear option - reset everything
mv .claude/tasks/doing/*.md .claude/tasks/todo/ 2>/dev/null
rm -rf .claude/locks/*.lock .claude/locks/.worker-*.active/
rm -rf .claude/state/*
```

### Check Agent Logs

```bash
# Find recent logs
ls -lt .claude/logs/claude-loop/ | head -5

# Read specific log
cat .claude/logs/claude-loop/<timestamp>/agent.log
```

## Known Limitations

1. **No task prioritization during parallel execution** - Each agent picks next available task independently.

2. **Date parsing assumes BSD or GNU date** - Works on macOS and Linux, may fail on other systems.

3. **Prompt files not validated at startup** - If a prompt file is missing, phase will fail at runtime.

4. **No inter-agent communication** - Agents work independently; can't coordinate on related tasks.

5. **TASKBOARD.md regeneration happens at run end** - Not updated during parallel execution until agents complete.

## Testing Checklist

When modifying `bin/agent`, verify:

- [ ] `shellcheck bin/agent` passes
- [ ] `bash -n bin/agent` passes
- [ ] Single agent run completes
- [ ] SKIP_* flags show "[SKIP]" in header
- [ ] DRY_RUN shows warning, no execution
- [ ] QUIET mode shows "quiet" in header
- [ ] Stale lock with dead PID is claimed
- [ ] Age-based stale detection works (use low AGENT_LOCK_TIMEOUT)
- [ ] Parallel agents don't pick same task
- [ ] Cleanup releases all locks on exit
