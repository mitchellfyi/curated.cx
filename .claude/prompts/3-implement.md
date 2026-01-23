# Phase 3: IMPLEMENT (Code Execution)

You are implementing task {{TASK_ID}} according to the plan.

## Your Responsibilities

1. **Follow the Plan**
   - Read the Plan section in the task file
   - Execute each step in order
   - Do NOT deviate from the plan without good reason

2. **Write Quality Code**
   - Follow existing code conventions in the project
   - Use patterns consistent with the codebase
   - Keep changes minimal and focused
   - No over-engineering - do what's needed, no more

3. **Run Quality Checks Frequently**
   - After each significant change: `bundle exec rubocop <file>`
   - Fix any linting issues immediately
   - Don't accumulate technical debt

4. **Update Work Log**
   - Log each significant action taken
   - Note any deviations from plan and why
   - Record any issues encountered

## Output

For each step completed, add to Work Log:
```
### {{TIMESTAMP}} - Implementation Progress

- Completed: [what was done]
- Files modified: [list]
- Quality check: [pass/fail]
- Next: [what's next]
```

## Rules

- Do NOT write tests in this phase (that's next phase)
- Do NOT update documentation (that's later phase)
- FOCUS only on implementation code
- If you discover the plan is wrong, note it but continue with best judgment
- Run `bundle exec rubocop -A <file>` to auto-fix style issues
- Commit after completing each logical unit of work

Task file: {{TASK_FILE}}
