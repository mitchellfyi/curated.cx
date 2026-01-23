# CLAUDE.md - Agent Operating Manual

This document is the single source of truth for autonomous agent operation in this repository.

## Quick Start

When prompted with "continue", "continue working", or similar:

```
1. Read this file completely
2. Execute the Operating Loop (Section A)
3. Complete quality gates after every major change
4. Commit with task reference when done
```

---

## A) Operating Loop

Execute this algorithm on every "continue working" run:

```
STEP 1: CHECK DOING
  - Look in .claude/tasks/doing/
  - If a task file exists:
    - Read the task file
    - Resume work from the Work Log
    - Continue to STEP 4

STEP 2: PICK FROM TODO
  - Look in .claude/tasks/todo/
  - If task files exist:
    - Sort by priority (filename prefix: PPP-SSS-slug)
      - PPP = priority (001=critical, 002=high, 003=medium, 004=low)
      - SSS = sequence within priority
    - Check dependencies (blockedBy field)
    - Pick first unblocked task
    - Move file from todo/ to doing/
    - Update status field in file to "doing"
    - Continue to STEP 4

STEP 3: CREATE NEW TASK
  - If todo/ is empty:
    - Read MISSION.md, README.md, MISSION_TASKS.md
    - Analyze current repo state (what exists, what's missing)
    - Identify the single most impactful next task
    - Create task file using template in _templates/task.md
    - Place in .claude/tasks/todo/
    - Move to doing/ immediately
    - Continue to STEP 4

STEP 4: EXECUTE TASK
  For the task in doing/:

  a) PLAN
    - Read all relevant files
    - Write implementation plan in task's Plan section
    - Identify files to create/modify
    - Identify tests needed

  b) IMPLEMENT
    - Make changes in small, reviewable chunks
    - Update Work Log after each significant action
    - Run quality gates after every major change (see Section D)

  c) TEST
    - Write tests for new functionality
    - Run existing tests to ensure no regressions
    - Update Work Log with test results

  d) REVIEW
    - Self-review the changes
    - Check for edge cases, security issues
    - Verify acceptance criteria are met

  e) COMPLETE
    - Run final quality gates
    - Update task status to "done"
    - Update completed timestamp
    - Add completion summary to Work Log
    - Move file from doing/ to done/
    - Commit with message referencing task ID
    - Regenerate TASKBOARD.md

STEP 5: CONTINUE OR STOP
  - If more tasks remain and within run limit: go to STEP 1
  - Otherwise: stop and report summary
```

---

## B) Repo Discovery

### Auto-Detection Commands

Run these to discover what's available:

```bash
# Ruby/Rails
[ -f Gemfile ] && echo "Ruby project"
[ -f bin/rails ] && echo "Rails available: bin/rails"
bundle list 2>/dev/null | grep -E "rspec|minitest|rubocop|brakeman|bundler-audit|standard|erb_lint"

# Node/JS
[ -f package.json ] && echo "Node project"
cat package.json 2>/dev/null | grep -E '"(test|lint|format)"'

# CI
[ -f .github/workflows/*.yml ] && echo "GitHub Actions CI"
[ -f .gitlab-ci.yml ] && echo "GitLab CI"
[ -f Makefile ] && echo "Makefile available"
```

### This Repository's Tools

**Primary Quality Command (ALWAYS USE THIS):**
```bash
./bin/quality  # Runs ALL 12 quality gates - MANDATORY before commit
```

#### Quality & Testing Tools

| Category | Tool | Command |
|----------|------|---------|
| **Quality (All)** | Full Suite | `./bin/quality` |
| Ruby Style | RuboCop | `bundle exec rubocop` |
| Ruby Style Fix | RuboCop | `bundle exec rubocop -A` |
| ERB Style | ERB Lint | `bundle exec erb_lint --lint-all` |
| Security | Brakeman | `bundle exec brakeman -q` |
| Security | Bundle Audit | `bundle exec bundle-audit check --update` |
| Tests | RSpec | `bundle exec rspec` |
| Tests (Fast) | RSpec (no slow) | `bundle exec rspec --exclude-pattern 'spec/{performance,system}/**/*'` |
| JS Lint | ESLint | `npm run lint` |
| JS Format | Prettier | `npm run format:check` |
| i18n | i18n-tasks | `bundle exec i18n-tasks health` |
| Model Annotations | Annotaterb | `bundle exec annotaterb models` |

#### Development Scripts

| Script | Purpose |
|--------|---------|
| `./bin/setup` | Setup development environment |
| `./bin/dev` | Start development server with Guard |
| `./bin/quality` | **MANDATORY** - Run ALL quality checks |
| `bundle exec guard` | Real-time quality monitoring |
| `./script/dev/setup-quality-automation` | Setup autonomous quality system |
| `./script/dev/pre-push-quality` | Extended pre-push validation |
| `./script/dev/quality-dashboard` | Live quality metrics and status |
| `./script/dev/quality-check-file` | File-specific quality checks |
| `./script/dev/i18n-check-file` | i18n compliance for templates |
| `./script/dev/route-test-check` | Route testing validation |
| `./script/dev/migration-check` | Migration safety analysis |
| `./script/dev/i18n` | Manage i18n translations |
| `./script/dev/migrations` | Database migration safety tools |
| `./script/dev/anti-pattern-detection` | Detect code anti-patterns |

#### The 12 Autonomous Quality Gates

The `./bin/quality` script enforces these gates:

1. **Code Style**: Zero RuboCop violations (Rails Omakase) + SOLID principles
2. **Security**: Zero Brakeman high/medium issues + Bundle Audit
3. **Tests**: 100% passing, 80% minimum coverage + Test Pyramid compliance
4. **Route Testing**: Every route must have corresponding tests
5. **i18n**: All static text uses translation keys
6. **Template Quality**: ERB lint compliance + semantic HTML
7. **SEO**: Meta tags, structured data, XML sitemaps
8. **Accessibility**: WCAG 2.1 AA compliance via axe-core testing
9. **Performance**: No N+1 queries + response time monitoring
10. **Database**: Proper indexes, constraints, migration safety
11. **Multi-tenant**: acts_as_tenant verification + data isolation
12. **Documentation**: Synchronization and consistency checks

### Discovery Priority

1. **Always run**: `./bin/quality` - comprehensive 12-gate check
2. **Quick feedback**: RuboCop, ESLint, Prettier - fast style checks
3. **Safety critical**: Brakeman, bundle-audit - security before commit
4. **Validation**: RSpec tests - must pass before done
5. **Optional**: Performance tests, accessibility tests - run when relevant

---

## C) Task Lifecycle

### Task ID Format

```
PPP-SSS-slug.md

PPP = Priority (001-004)
  001 = Critical (blocking, security, broken)
  002 = High (important feature, significant bug)
  003 = Medium (normal work, improvements)
  004 = Low (nice-to-have, cleanup)

SSS = Sequence (001-999)
  Within same priority, lower = do first

slug = kebab-case description (max 50 chars)

Examples:
  001-001-fix-security-vulnerability.md
  002-001-add-user-authentication.md
  002-002-add-password-reset.md
  003-001-refactor-user-model.md
```

### Task States

```
.claude/tasks/
  todo/     <- Planned, ready to start
  doing/    <- In progress (max 1 task at a time)
  done/     <- Completed with logs
  _templates/ <- Task file template
```

### Moving Tasks

When changing state, physically move the file:

```bash
# Pick up task
mv .claude/tasks/todo/003-001-example.md .claude/tasks/doing/

# Complete task
mv .claude/tasks/doing/003-001-example.md .claude/tasks/done/
```

### Task File Template

Located at `.claude/tasks/_templates/task.md`

Required sections:
- **Title**: Clear, actionable description
- **Context**: Why this task exists
- **Acceptance Criteria**: Definition of done (checkboxes)
- **Plan**: Step-by-step implementation approach
- **Work Log**: Timestamped record of actions and outcomes
- **Testing Evidence**: Commands run, results
- **Notes**: Observations, blockers, decisions
- **Links**: Related files, PRs, issues

---

## D) Quality Gates

### When to Run

Run quality checks after every "major change":
- Adding/modifying a file with significant logic
- Changing database schema
- Adding new dependencies
- Modifying configuration
- Before committing

### Quick Check (During Development)

```bash
# Ruby changes
bundle exec rubocop --only-git-dirty 2>/dev/null || bundle exec rubocop

# JS changes
npm run lint 2>/dev/null || true
npm run format:check 2>/dev/null || true
```

### Full Check (Before Commit)

```bash
# Preferred: use bin/quality if available
[ -x bin/quality ] && bin/quality

# Or run individually:
bundle exec rubocop
bundle exec erb_lint --lint-all
bundle exec brakeman -q
bundle exec bundle-audit check --update
bundle exec rspec --exclude-pattern 'spec/{performance,system}/**/*'
```

### Quality Failure Protocol

If a quality check fails:
1. **STOP** - do not continue with more changes
2. **FIX** - address the failure immediately
3. **RE-RUN** - verify the fix resolves the issue
4. **LOG** - note the failure and fix in Work Log
5. **CONTINUE** - only after all checks pass

### Test Coverage Rules

- **New code**: Must have tests
- **Bug fixes**: Must have regression test
- **Modified code**: Existing tests must still pass
- **No tests exist**: Add tests for area being touched

---

## E) Commit Policy

### Commit Requirements

1. **All quality gates must pass** - never commit failing checks
2. **Task reference required** - include task ID in message
3. **Atomic commits** - one logical change per commit
4. **Working state** - app must work after commit

### Commit Message Format

```
<type>: <description>

[optional body]

Task: <task-id>
Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code restructure without behavior change
- `test`: Adding/updating tests
- `docs`: Documentation only
- `style`: Formatting, no logic change
- `chore`: Maintenance, dependencies

Example:
```
feat: add user authentication system

Implements login/logout with session management.
Adds User model with secure password handling.

Task: 002-001-add-user-authentication
Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
```

### What NOT to Commit

- Broken tests
- Security vulnerabilities
- Debug code or console.log
- Commented-out code
- TODO comments without task reference
- Credentials or secrets
- Large binary files

---

## F) Failure Modes

### When Stuck

1. **Document the blocker** in task Work Log
2. **Identify the type**:
   - Missing information -> Add question to Notes
   - Technical limitation -> Research alternatives
   - Scope creep -> Split into subtasks
   - External dependency -> Create blocked task

3. **If blocked for > 3 attempts**:
   - Move task back to todo/ with blocker noted
   - Pick a different task
   - Leave clear handoff notes

### Flaky Tests

1. Re-run the test 3 times
2. If intermittent:
   - Note in Work Log
   - Check for race conditions, timing issues
   - Add retry logic if appropriate
   - Or mark as known flaky with comment

### Scope Explosion

If a task grows beyond original estimate:
1. Complete the minimum viable version
2. Create follow-up tasks for additional scope
3. Commit what's done
4. Move to done with note about follow-ups

### Dependency Conflicts

1. Log the conflict in Work Log
2. Try: `bundle update <gem>` or `npm update <package>`
3. If unresolvable:
   - Document in Notes
   - Check for alternatives
   - Create separate task for dependency upgrade

### Environment Issues

If local environment breaks:
1. Log the issue
2. Try: `bin/setup` if available
3. Check: Ruby version, Node version, database
4. Reset: `bundle install && npm install`

---

## G) Taskboard

### Generate Taskboard

Run `.claude/scripts/taskboard.sh` to regenerate `TASKBOARD.md`:

```bash
.claude/scripts/taskboard.sh
```

### Taskboard Location

`TASKBOARD.md` in repo root - human-readable overview of all tasks.

---

## H) Scripts

### bin/agent

Main entry point for **FULLY AUTONOMOUS + SELF-HEALING** operation. Runs Claude in dangerous mode with all permissions bypassed and automatic recovery from failures.

```bash
# Run 5 tasks (default)
./bin/agent

# Run specific number of tasks
./bin/agent 3

# Run 1 task
./bin/agent 1
```

**Environment Variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| `CLAUDE_MODEL` | `opus` | Model to use (opus, sonnet, haiku) |
| `CLAUDE_TIMEOUT` | `600` | Timeout per task in seconds |
| `AGENT_DRY_RUN` | `0` | Set to 1 to preview without executing |
| `AGENT_VERBOSE` | `0` | Set to 1 for more output |
| `AGENT_MAX_RETRIES` | `3` | Max retry attempts per task |
| `AGENT_RETRY_DELAY` | `5` | Base delay between retries (exponential backoff) |
| `AGENT_NO_RESUME` | `0` | Set to 1 to skip resuming interrupted sessions |

**Self-Healing Features:**

| Feature | Description |
|---------|-------------|
| **Auto-Retry** | Retries failed tasks up to 3 times with exponential backoff |
| **Session Persistence** | Saves state to `.claude/state/` for crash recovery |
| **Auto-Resume** | Detects interrupted sessions and resumes from last iteration |
| **Health Checks** | Validates environment before each run (CLI, dirs, disk space) |
| **Circuit Breaker** | Pauses 30s after 3 consecutive failures to avoid hammering |
| **Error Detection** | Recognizes rate limits, timeouts, server errors for smart retry |
| **Graceful Cleanup** | Regenerates taskboard on exit (normal or interrupted) |

**How Self-Healing Works:**

```
1. Health check runs before starting
2. On failure:
   a. Save session state (iteration, status, logs)
   b. Wait with exponential backoff (5s, 10s, 20s...)
   c. Retry with --continue flag to resume
   d. After 3 failures: circuit breaker pauses 30s
3. On crash/kill:
   a. Next run detects interrupted session
   b. Resumes from last iteration automatically
4. On completion:
   a. Clears session state
   b. Regenerates taskboard
```

**CLI Flags Used (Dangerous Mode):**

```bash
claude \
  --dangerously-skip-permissions \   # Bypass ALL permission checks
  --permission-mode bypassPermissions \  # Additional bypass mode
  -p \                                # Non-interactive print mode
  --model opus \                      # Specify model
  --continue \                        # Resume previous session (on retry)
  "continue working"                  # The prompt
```

### .claude/scripts/taskboard.sh

Generates TASKBOARD.md from task files.

```bash
.claude/scripts/taskboard.sh
```

---

## I) File Reference

```
.claude/
  tasks/
    todo/          <- Tasks ready to work
    doing/         <- Current task (max 1)
    done/          <- Completed tasks
    _templates/
      task.md      <- Task template
  scripts/
    taskboard.sh   <- Generate TASKBOARD.md
  logs/
    claude-loop/   <- Run logs by timestamp

bin/
  agent            <- Main agent script

CLAUDE.md          <- This file
TASKBOARD.md       <- Generated task overview
MISSION.md         <- Project goals
README.md          <- Project overview
```

---

## J) Operating Principles

1. **Read before write** - Always understand context first
2. **Small changes** - Easier to review, easier to revert
3. **Test everything** - No untested code
4. **Log everything** - Future you (or another agent) will thank you
5. **Fail fast** - Don't continue on broken state
6. **Be autonomous** - Make decisions, don't wait for input
7. **Be reversible** - Prefer changes that can be undone
8. **Be transparent** - Document decisions and trade-offs

---

## K) Emergency Procedures

### Reset Stuck State

```bash
# Move any doing task back to todo
mv .claude/tasks/doing/*.md .claude/tasks/todo/ 2>/dev/null

# Clear logs older than 7 days
find .claude/logs -mtime +7 -delete
```

### Validate System

```bash
# Check folder structure
ls -la .claude/tasks/{todo,doing,done,_templates}

# Count tasks by state
echo "TODO: $(ls .claude/tasks/todo/*.md 2>/dev/null | wc -l)"
echo "DOING: $(ls .claude/tasks/doing/*.md 2>/dev/null | wc -l)"
echo "DONE: $(ls .claude/tasks/done/*.md 2>/dev/null | wc -l)"
```

---

## Appendix: Quick Reference Card

```
CONTINUE WORKING LOOP:
  doing? -> resume it
  todo?  -> pick highest priority unblocked
  empty? -> create from MISSION.md

QUALITY GATES:
  bin/quality (preferred)
  -or- rubocop + rspec + brakeman

COMMIT FORMAT:
  <type>: <description>
  Task: <task-id>
  Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>

TASK PRIORITY:
  001 = Critical
  002 = High
  003 = Medium
  004 = Low

WHEN STUCK:
  1. Log it
  2. Try 3 times
  3. Move back to todo
  4. Pick something else
```
