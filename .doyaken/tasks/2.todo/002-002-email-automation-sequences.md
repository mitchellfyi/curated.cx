# Task: Email Automation Sequences

## Metadata

| Field       | Value                                                  |
| ----------- | ------------------------------------------------------ |
| ID          | `002-002-email-automation-sequences`                   |
| Status      | `todo`                                                 |
| Priority    | `002` High                                             |
| Created     | `2026-01-30 15:30`                                     |
| Started     |                                                        |
| Completed   |                                                        |
| Blocked By  |                                                        |
| Blocks      |                                                        |
| Assigned To |                                                        |
| Assigned At |                                                        |

---

## Context

Why does this task exist? What problem does it solve?

- **Competitive Gap**: Substack is rolling out email automations to all creators in 2026. Kit (ConvertKit) has 28+ pre-built automation templates. beehiiv offers expanded automation capabilities. Curated has only basic weekly/daily digest emails.
- **User Value**: Publishers need automated onboarding sequences, welcome series, and re-engagement campaigns to maximize subscriber value.
- **Industry Trend**: Email automation is table stakes for creator platforms in 2026.
- **RICE Score**: 240 (Reach: 800, Impact: 3, Confidence: 100%, Effort: 1 person-week)

**Problem**: Curated only sends periodic digest emails. Publishers cannot create automated email sequences for onboarding, nurturing, or re-engagement.

**Solution**: A visual email automation builder supporting triggered sequences (welcome series, milestone emails, re-engagement) with conditional logic.

---

## Acceptance Criteria

All must be checked before moving to done:

- [ ] EmailSequence model for defining automation flows
- [ ] EmailStep model for individual emails in a sequence
- [ ] Trigger types: subscriber_joined, days_since_joined, inactivity, referral_milestone
- [ ] Delay configuration between steps (immediate, 1 day, 3 days, 7 days, etc.)
- [ ] Welcome email sequence template
- [ ] Visual sequence builder in admin
- [ ] Sequence analytics (open rates, click rates per step)
- [ ] Subscriber progression tracking through sequences
- [ ] Stop conditions (unsubscribe, completed, manually removed)
- [ ] Tests written and passing
- [ ] Quality gates pass
- [ ] Changes committed with task reference

---

## Plan

Step-by-step implementation approach:

1. **Step 1**: Create EmailSequence model
   - Files: `app/models/email_sequence.rb`, `db/migrate/xxx_create_email_sequences.rb`
   - Actions: name, trigger_type, site_id, enabled, settings (JSONB)

2. **Step 2**: Create EmailStep model
   - Files: `app/models/email_step.rb`, `db/migrate/xxx_create_email_steps.rb`
   - Actions: sequence_id, position, delay_days, subject, body, settings

3. **Step 3**: Create SequenceEnrollment model
   - Files: `app/models/sequence_enrollment.rb`
   - Actions: Track subscriber progress through sequences

4. **Step 4**: Create ProcessEmailSequencesJob
   - Files: `app/jobs/process_email_sequences_job.rb`
   - Actions: Check enrollments, send due emails, update progress

5. **Step 5**: Create enrollment triggers
   - Files: `app/services/sequence_enrollment_service.rb`
   - Actions: Auto-enroll on subscription, referral, etc.

6. **Step 6**: Create admin sequence builder
   - Files: `app/controllers/admin/email_sequences_controller.rb`, `app/views/admin/email_sequences/`
   - Actions: CRUD for sequences and steps, visual editor

7. **Step 7**: Add sequence analytics
   - Files: Track opens/clicks per step, show in admin

8. **Step 8**: Write tests
   - Files: `spec/models/email_sequence_spec.rb`, `spec/jobs/process_email_sequences_job_spec.rb`
   - Coverage: Enrollment, progression, sending, analytics

---

## Work Log

_No work started yet._

---

## Testing Evidence

_No tests run yet._

---

## Notes

- Start with simple trigger types, expand later
- Use existing ActionMailer infrastructure
- Consider rate limiting to avoid spam issues
- Pre-built templates: Welcome (3 emails), Re-engagement (2 emails)
- Integrate with existing DigestSubscription model

---

## Links

- Research: Kit automation templates, Substack automation rollout
- Related: DigestSubscription, SendDigestEmailsJob
