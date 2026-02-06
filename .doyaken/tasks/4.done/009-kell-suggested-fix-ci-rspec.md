# Task: Fix RSpec CI Failure - DigestSubscription Mailer

## Description
CI is failing on RSpec tests. The DigestSubscription mailer test is failing, likely related to after_commit callback handling with truncation strategy.

## Acceptance Criteria
- [ ] Investigate RSpec test failure in CI
- [ ] Fix DigestSubscription mailer test
- [ ] Ensure all RSpec tests pass locally with `bundle exec rspec`
- [ ] Verify CI passes after fix

## Technical Notes
- Recent commit attempted fix: "use truncation strategy for after_commit callback"
- May need to check DatabaseCleaner strategy configuration
- Test file: `spec/mailers/digest_subscription_mailer_spec.rb`

## Priority
**HIGH** - CI is broken, blocks deployments

## Created By
kell-suggested (pending approval)
