# Self-Healing CI Workflow

## Overview

The self-healing CI workflow automatically creates GitHub issues and assigns them to Copilot's coding agent when CI fails on the `main` branch. This enables autonomous detection and fixing of build failures, providing a safety net for regressions and unexpected failures.

**This is NOT a replacement for proper CI practices.** It's a safety mechanism for failures that slip through code review.

## How It Works

### Trigger Mechanism

The workflow uses GitHub's `workflow_run` event to monitor the main CI workflow:

```yaml
on:
  workflow_run:
    workflows: ["CI"]
    types: [completed]
    branches: [main]
```

It only triggers when:
- The CI workflow completes with a `failure` conclusion
- The failure occurred on the `main` branch
- The workflow was not cancelled or skipped

### Failure Detection and Log Collection

When triggered, the workflow:

1. **Fetches Failed Jobs**: Uses the GitHub Actions API to retrieve all jobs from the failed workflow run
2. **Filters Failures**: Identifies jobs with a `failure` conclusion
3. **Downloads Logs**: Retrieves the full log output for each failed job
4. **Truncates Logs**: Takes the last 150-200 lines per job to stay within GitHub issue body limits while capturing relevant failure context

### Duplicate Prevention

Before creating a new issue, the workflow:

1. Searches for existing open issues with both `ci-fix` and `automated` labels
2. If an existing issue is found:
   - Adds a comment with the new failure information
   - Increments the retry counter
   - After 3 retry attempts, adds a `needs-human` label and stops auto-retry

### Issue Creation

For new failures (no existing open issue), the workflow creates an issue with:

**Title Format:**
```
[CI Fix] Build failure on `main` (abc1234)
```

**Labels:**
- `ci-fix` - Identifies this as an automated CI fix request
- `automated` - Marks the issue as created by automation

**Assignee:**
- `copilot` - GitHub Copilot's coding agent will automatically work on this

**Body Template:**
```markdown
## CI Failure — Auto-generated

The CI workflow failed on branch `main` at commit `<full-sha>`.

**Failed run:** <link-to-workflow-run>

## Task

Analyze the failure logs below and fix the code that is causing CI to fail.

**Rules:**
- Fix the root cause in the source code, tests, or configuration
- Do NOT skip, disable, or mark any tests as expected failures
- Do NOT add `continue-on-error` or any other workaround that masks the failure
- Run the full test suite locally before submitting your PR
- Keep your changes minimal and focused on the fix

## Failure Logs

### Job: <job-name>

[View full job logs](<link>)

```
<last-150-200-lines-of-logs>
```
```

## Safety Features

### Rate Limiting

- **Maximum Retries**: 3 attempts per issue
- **Escalation**: After 3 failed attempts, adds `needs-human` label
- **No Spam**: Will not create duplicate issues if one already exists

### Scope Limitations

The workflow:
- ✅ **Only runs on `main` branch** - Feature branch failures are the developer's responsibility
- ✅ **Only runs for CI workflow failures** - Won't self-heal other workflows
- ✅ **Only runs for actual failures** - Ignores cancelled or skipped workflows
- ✅ **Never self-heals itself** - The workflow is scoped to only monitor the "CI" workflow, preventing infinite loops

### Permissions

The workflow requires minimal permissions:
```yaml
permissions:
  issues: write    # Create and comment on issues
  actions: read    # Read workflow run data
  checks: read     # Read check suite status
  contents: read   # Checkout repository code
```

## Label Management

The workflow automatically creates labels if they don't exist:

| Label | Color | Description |
|-------|-------|-------------|
| `ci-fix` | #d73a4a (red) | Automated CI failure fix request |
| `automated` | #0e8a16 (green) | Created by automation |
| `needs-human` | #fbca04 (yellow) | Requires human intervention |

## Workflow Lifecycle

### Scenario 1: First Failure
1. CI fails on main branch
2. Self-healing workflow creates issue #123
3. Assigns to `copilot`
4. Copilot analyzes logs, creates fix PR
5. PR is reviewed and merged
6. Issue #123 is closed

### Scenario 2: Repeated Failure
1. CI fails on main branch
2. Self-healing workflow finds existing issue #123
3. Adds comment with new failure logs (Attempt 1/3)
4. Copilot iterates on the fix
5. After 3 failed attempts → adds `needs-human` label
6. Human reviews and fixes manually

### Scenario 3: Feature Branch Failure
1. CI fails on feature branch `feature/new-thing`
2. Self-healing workflow **does not trigger** (not main branch)
3. Developer fixes their own feature branch

## Testing the Workflow

### Manual Test Plan

1. **Test Basic Issue Creation**
   ```bash
   # On a feature branch, intentionally break a test
   # Example: Add `expect(true).to eq(false)` to a spec
   git checkout -b test/break-ci
   # Make breaking change
   git commit -m "Test: Intentionally break CI"
   git push
   # Create PR to main and merge
   # After merge, check that self-healing issue was created
   ```

2. **Test Duplicate Detection**
   ```bash
   # Before closing the issue from test 1:
   # Push another breaking change to main
   # Verify that a comment is added to existing issue, not a new issue
   ```

3. **Test Retry Limit**
   ```bash
   # Push 3 more breaking changes (without fixing)
   # Verify that after 3 attempts, `needs-human` label is added
   ```

### Verification Checklist

- [ ] Issue created with correct title format
- [ ] Issue has `ci-fix` and `automated` labels
- [ ] Issue assigned to `copilot`
- [ ] Issue body contains full SHA and run URL
- [ ] Issue body contains truncated logs (not full logs)
- [ ] Duplicate detection prevents multiple issues
- [ ] Retry counter works (comments show "Attempt X/3")
- [ ] `needs-human` label added after 3 attempts
- [ ] Workflow doesn't trigger on feature branches
- [ ] Workflow doesn't trigger for cancelled runs

## Auto-Merge Implementation (Optional)

The problem statement mentions an optional auto-merge workflow for Copilot's fix PRs. This is **not currently implemented** due to GitHub's security constraints.

### Why Not Implemented

GitHub requires that PR approvals come from a different account/context than the PR author:
- A workflow using `GITHUB_TOKEN` cannot approve PRs it triggered
- Copilot PRs would need a separate authentication mechanism for approval

### Options for Future Implementation

If you want to implement auto-merge:

#### Option 1: GitHub App (Recommended)
- Create a GitHub App with PR approval permissions
- Install app on repository
- Use app credentials for approval workflow
- **Pros**: Most secure, proper authentication scoping
- **Cons**: Requires GitHub App setup and management

#### Option 2: Bot Account
- Create a dedicated bot GitHub account
- Add as repository collaborator with write access
- Use bot account's PAT for approval workflow
- **Pros**: Simpler setup than GitHub App
- **Cons**: Requires managing another GitHub account, less secure

#### Option 3: Manual Review (Current)
- Let self-healing create the issue
- Let Copilot create the fix PR
- Require human review and merge
- **Pros**: Maintains human oversight, no additional setup
- **Cons**: Not fully "self-healing", requires manual intervention

### Example Auto-Merge Workflow (Not Implemented)

If you choose to implement this, here's a template:

```yaml
name: Auto-Merge Copilot Fixes

on:
  pull_request:
    branches: [main]

jobs:
  auto-approve-and-merge:
    if: startsWith(github.head_ref, 'copilot/')
    runs-on: ubuntu-latest
    steps:
      - name: Wait for CI
        uses: lewagon/wait-on-check-action@v1.3.1
        with:
          ref: ${{ github.event.pull_request.head.sha }}
          check-name: 'CI'
          repo-token: ${{ secrets.GITHUB_TOKEN }}
          
      - name: Auto-approve
        uses: hmarr/auto-approve-action@v3
        with:
          github-token: ${{ secrets.BOT_GITHUB_TOKEN }}
          
      - name: Enable auto-merge
        run: gh pr merge --auto --squash "${{ github.event.pull_request.number }}"
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Note**: This requires `BOT_GITHUB_TOKEN` to be a personal access token from a different account.

## Trade-offs and Considerations

### Benefits
- ✅ Rapid response to main branch breakage
- ✅ Reduces time to fix from hours/days to minutes
- ✅ Autonomous fixing frees up developer time
- ✅ Comprehensive logging aids debugging
- ✅ Rate limiting prevents runaway automation

### Limitations
- ⚠️ Requires Copilot to be effective at fixing issues
- ⚠️ May miss complex issues requiring human judgment
- ⚠️ Log truncation might omit relevant context
- ⚠️ Not suitable for security-critical fixes (needs human review)
- ⚠️ Copilot's success rate depends on issue clarity

### When to Disable

Consider disabling or pausing this workflow when:
- Major refactoring is underway (too many expected failures)
- CI infrastructure itself is unstable
- Multiple rapid commits expected on main
- Security incident response (need full human control)

To disable temporarily:
```yaml
# In .github/workflows/self-healing-ci.yml
# Comment out the 'on:' section or entire workflow
```

## Monitoring and Maintenance

### Regular Checks

- Review closed issues with `ci-fix` label to assess success rate
- Monitor issues with `needs-human` label (fix automation limitations)
- Check for issues opened but never fixed (Copilot assignment failures)

### Metrics to Track

- **Success Rate**: % of ci-fix issues resolved by Copilot without human intervention
- **Time to Fix**: Average time from issue creation to PR merge
- **Retry Rate**: How often issues require multiple attempts
- **Escalation Rate**: % of issues requiring `needs-human` intervention

### Improvements

Potential future enhancements:
- Integration with Slack/Teams for notifications
- More intelligent log truncation (keep error messages, trim noise)
- Context-aware issue body (include recent commits, relevant files)
- Integration with deployment rollback mechanisms
- Learning from past fixes to improve issue descriptions

## Troubleshooting

### Issue Not Created

**Problem**: CI fails but no issue is created

**Checks**:
1. Verify failure was on `main` branch (check workflow run)
2. Confirm CI workflow conclusion is `failure` (not `cancelled`)
3. Check self-healing workflow run for errors
4. Verify workflow has proper permissions in repository settings

### Duplicate Issues Created

**Problem**: Multiple issues for same failure

**Checks**:
1. Verify both `ci-fix` AND `automated` labels are on issues
2. Check if search query in workflow is correct
3. Review timing (concurrent failures might race)

### Copilot Not Responding

**Problem**: Issue created but Copilot doesn't create PR

**Checks**:
1. Verify Copilot is enabled for repository
2. Check that `copilot` is a valid assignee
3. Review issue body clarity (Copilot needs clear instructions)
4. Manually assign or mention @copilot in issue

### Logs Too Large

**Problem**: Issue body exceeds GitHub limits

**Solution**: Adjust `maxLinesPerJob` in workflow (currently 200):
```javascript
const maxLinesPerJob = 150; // Reduce from 200
```

## Related Documentation

- [CI Workflow Documentation](.github/workflows/ci.yml)
- [GitHub Actions workflow_run event](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#workflow_run)
- [GitHub Copilot](https://docs.github.com/en/copilot)
- [GitHub Actions API](https://docs.github.com/en/rest/actions)

## Support

For issues or questions:
1. Check existing issues with `ci-fix` label for examples
2. Review self-healing workflow run logs
3. Open a discussion in the repository
4. Contact the repository maintainers

---

**Last Updated**: 2026-02-10
**Workflow Version**: 1.0
**Status**: Active
