# Task: Email Automation Sequences

## Metadata

| Field       | Value                                                  |
| ----------- | ------------------------------------------------------ |
| ID          | `002-002-email-automation-sequences`                   |
| Status      | `doing`                                                |
| Priority    | `002` High                                             |
| Created     | `2026-01-30 15:30`                                     |
| Started     | `2026-01-30 16:05`                                     |
| Completed   |                                                        |
| Blocked By  |                                                        |
| Blocks      |                                                        |
| Assigned To | `worker-1` |
| Assigned At | `2026-01-30 16:00` |

---

## Context

**Intent**: BUILD

### Background

Curated currently provides only periodic digest emails (weekly/daily) via `SendDigestEmailsJob` and `DigestMailer`. Publishers cannot create automated email sequences for subscriber lifecycle events such as onboarding, nurturing, or re-engagement.

### Competitive Context

- **Substack**: Rolling out email automations to all creators in 2026
- **Kit (ConvertKit)**: 28+ pre-built automation templates
- **beehiiv**: Expanded automation capabilities

### User Value

Publishers need automated sequences to:
1. **Welcome new subscribers** - First impression matters, introduce the publication
2. **Nurture engagement** - Drive subscribers to engage with content
3. **Re-engage inactive subscribers** - Win back churning subscribers
4. **Celebrate referral milestones** - Automated reward emails (already partially done)

### Existing Infrastructure (will integrate with)

| Component | Purpose | Key Patterns |
|-----------|---------|--------------|
| `DigestSubscription` | Subscriber record | `SiteScoped`, `last_sent_at` tracking, `unsubscribe_token` |
| `DigestMailer` | Sends digest emails | Cascading from address (site→tenant→default), i18n subjects |
| `SendDigestEmailsJob` | Background email sending | `find_each(batch_size: 100)`, `ActsAsTenant.with_tenant`, `deliver_later` |
| `ReferralMailer` | Referral notifications | Event-based emails, same from address pattern |
| `Referral` model | Referral tracking | Status enum (pending→confirmed→rewarded→cancelled) |

### RICE Score
- **Reach**: 800 subscribers
- **Impact**: 3 (high)
- **Confidence**: 100%
- **Effort**: 1 person-week
- **Score**: 240

---

## Acceptance Criteria

All must be checked before moving to done:

### Models & Data Layer
- [ ] `EmailSequence` model: `site_id`, `name`, `trigger_type` (enum), `enabled`, `settings` (jsonb)
- [ ] `EmailStep` model: `email_sequence_id`, `position`, `delay_seconds`, `subject`, `body_html`, `body_text`
- [ ] `SequenceEnrollment` model: `email_sequence_id`, `digest_subscription_id`, `status` (enum: active/completed/stopped), `current_step_id`, `enrolled_at`, `completed_at`
- [ ] `SequenceEmail` model: `sequence_enrollment_id`, `email_step_id`, `sent_at`, `status` (enum: pending/sent/failed)
- [ ] Proper foreign keys and indexes for all new tables
- [ ] `SiteScoped` concern included on site-owned models

### Trigger Types (Phase 1)
- [ ] `subscriber_joined` - Triggers when DigestSubscription is created
- [ ] `referral_milestone` - Triggers when referral count reaches threshold (integrate with existing `ReferralRewardService`)

### Email Sending
- [ ] `ProcessSequenceEnrollmentsJob` - Processes pending emails for active enrollments
- [ ] `SequenceMailer` - ActionMailer for sending sequence emails
- [ ] Integration with existing from-address pattern (site→tenant→default cascade)
- [ ] Respects subscription active status (stops if unsubscribed)
- [ ] Batch processing with `find_each(batch_size: 100)`

### Admin Interface
- [ ] `Admin::EmailSequencesController` with full CRUD
- [ ] `Admin::EmailStepsController` nested under sequences
- [ ] Index view: list sequences with status, trigger type, enrollment count
- [ ] Show view: sequence details with steps timeline
- [ ] Form views: create/edit sequence and steps
- [ ] Enable/disable toggle for sequences

### Testing
- [ ] Model specs for all new models with validations and associations
- [ ] Job spec for `ProcessSequenceEnrollmentsJob`
- [ ] Mailer spec for `SequenceMailer`
- [ ] Request specs for admin controllers
- [ ] Factory definitions for all new models

### Quality
- [ ] Tests written and passing
- [ ] Quality gates pass
- [ ] i18n keys for all user-facing strings
- [ ] Changes committed with task reference

---

## Plan

### Gap Analysis

| Criterion | Status | Gap |
|-----------|--------|-----|
| `EmailSequence` model | none | Create migration, model, factory, spec |
| `EmailStep` model | none | Create migration, model, factory, spec |
| `SequenceEnrollment` model | none | Create migration, model, factory, spec |
| `SequenceEmail` model | none | Create migration, model, factory, spec |
| Foreign keys & indexes | none | Include in migrations |
| `SiteScoped` concern | partial | Pattern exists in `Referral`, apply to new models |
| `subscriber_joined` trigger | none | Add callback in `DigestSubscription` |
| `referral_milestone` trigger | none | Add call in `ReferralRewardService.check_and_award!` |
| `ProcessSequenceEnrollmentsJob` | none | Create (mirror `SendDigestEmailsJob` pattern) |
| `SequenceMailer` | none | Create (mirror `DigestMailer` from-address pattern) |
| Admin controllers | none | Create (mirror `ReferralRewardTiersController` pattern) |
| Admin views | none | Create all views |
| Request specs | none | Create (mirror `referral_reward_tiers_spec.rb` pattern) |
| i18n keys | none | Add to `en.yml` under `admin.email_sequences` |

### Risks

- [ ] **Email flooding on mass signup**: Batch processing (100 at a time) mitigates; rate limiting can be added later
- [ ] **Orphaned enrollments from deleted sequences**: Use `dependent: :destroy` on associations
- [ ] **Performance with many enrollments**: Index on `(status, scheduled_for)`, batch processing
- [ ] **Race condition on enrollment**: Use `find_or_create_by` with unique constraint
- [ ] **Integration with existing DigestSubscription callbacks**: Test thoroughly in isolation

### Steps

#### Step 1: Database Migrations

**1a. Create `email_sequences` table**
- File: `db/migrate/YYYYMMDDHHMMSS_create_email_sequences.rb`
- Columns: `site_id:references`, `name:string`, `trigger_type:integer`, `trigger_config:jsonb`, `enabled:boolean(default:false)`, timestamps
- Indexes: `site_id`, composite `(site_id, trigger_type, enabled)`
- Verify: Migration runs without errors

**1b. Create `email_steps` table**
- File: `db/migrate/YYYYMMDDHHMMSS_create_email_steps.rb`
- Columns: `email_sequence_id:references`, `position:integer`, `delay_seconds:integer(default:0)`, `subject:string`, `body_html:text`, `body_text:text`, timestamps
- Indexes: `email_sequence_id`, unique composite `(email_sequence_id, position)`
- Verify: Migration runs without errors

**1c. Create `sequence_enrollments` table**
- File: `db/migrate/YYYYMMDDHHMMSS_create_sequence_enrollments.rb`
- Columns: `email_sequence_id:references`, `digest_subscription_id:references`, `status:integer(default:0)`, `current_step_position:integer`, `enrolled_at:datetime`, `completed_at:datetime`, timestamps
- Indexes: unique composite `(email_sequence_id, digest_subscription_id)`, `status`
- Verify: Migration runs without errors

**1d. Create `sequence_emails` table**
- File: `db/migrate/YYYYMMDDHHMMSS_create_sequence_emails.rb`
- Columns: `sequence_enrollment_id:references`, `email_step_id:references`, `status:integer(default:0)`, `scheduled_for:datetime`, `sent_at:datetime`, timestamps
- Indexes: `sequence_enrollment_id`, composite `(status, scheduled_for)`
- Verify: `rails db:migrate` succeeds for all 4 migrations

---

#### Step 2: Models

**2a. EmailSequence model**
- File: `app/models/email_sequence.rb`
- Include `SiteScoped`
- `belongs_to :site`, `has_many :email_steps, dependent: :destroy`, `has_many :sequence_enrollments, dependent: :destroy`
- Enum: `trigger_type` (subscriber_joined: 0, referral_milestone: 1)
- Validations: presence of `name`, `trigger_type`; uniqueness of `name` scoped to `site_id`
- Scope: `.enabled`, `.for_trigger`
- Verify: `EmailSequence.new` in console

**2b. EmailStep model**
- File: `app/models/email_step.rb`
- `belongs_to :email_sequence`, `has_many :sequence_emails, dependent: :destroy`
- Validations: presence of `subject`, `body_html`; `position >= 0`, `delay_seconds >= 0`
- Scope: `.ordered` (order by position)
- Method: `delay_duration` returns `delay_seconds.seconds`
- Verify: `EmailStep.new` in console

**2c. SequenceEnrollment model**
- File: `app/models/sequence_enrollment.rb`
- `belongs_to :email_sequence`, `belongs_to :digest_subscription`, `has_many :sequence_emails, dependent: :destroy`
- Enum: `status` (active: 0, completed: 1, stopped: 2)
- Scope: `.active`, `.for_sequence`
- Methods: `stop!`, `complete!`, `next_step`, `schedule_next_email!`
- Verify: `SequenceEnrollment.new` in console

**2d. SequenceEmail model**
- File: `app/models/sequence_email.rb`
- `belongs_to :sequence_enrollment`, `belongs_to :email_step`
- Enum: `status` (pending: 0, sent: 1, failed: 2)
- Scopes: `.pending`, `.due` (where `scheduled_for <= Time.current`)
- Methods: `mark_sent!`, `mark_failed!`
- Verify: `SequenceEmail.new` in console

---

#### Step 3: Factories

**3a. email_sequences factory**
- File: `spec/factories/email_sequences.rb`
- Base: `site`, `name { "Welcome Sequence" }`, `trigger_type { :subscriber_joined }`
- Traits: `:enabled`, `:with_steps` (3 steps), `:referral_milestone_trigger`
- Verify: `FactoryBot.build(:email_sequence).valid?`

**3b. email_steps factory**
- File: `spec/factories/email_steps.rb`
- Base: `email_sequence`, `sequence { |n| n }` for position, `delay_seconds { 0 }`, `subject`, `body_html`, `body_text`
- Verify: `FactoryBot.build(:email_step).valid?`

**3c. sequence_enrollments factory**
- File: `spec/factories/sequence_enrollments.rb`
- Base: `email_sequence`, `digest_subscription`, `enrolled_at { Time.current }`
- Traits: `:active`, `:completed`, `:stopped`
- Verify: `FactoryBot.build(:sequence_enrollment).valid?`

**3d. sequence_emails factory**
- File: `spec/factories/sequence_emails.rb`
- Base: `sequence_enrollment`, `email_step`, `scheduled_for { Time.current }`
- Traits: `:pending`, `:sent`, `:failed`, `:due`, `:future`
- Verify: `FactoryBot.build(:sequence_email).valid?`

---

#### Step 4: Model Specs

**4a. email_sequence_spec.rb**
- File: `spec/models/email_sequence_spec.rb`
- Test: associations, validations, enums, scopes, SiteScoped inclusion
- Pattern: Mirror `spec/models/referral_spec.rb` structure
- Verify: `bundle exec rspec spec/models/email_sequence_spec.rb`

**4b. email_step_spec.rb**
- File: `spec/models/email_step_spec.rb`
- Test: associations, validations, `ordered` scope, `delay_duration` method
- Verify: `bundle exec rspec spec/models/email_step_spec.rb`

**4c. sequence_enrollment_spec.rb**
- File: `spec/models/sequence_enrollment_spec.rb`
- Test: associations, validations, status enum, `stop!`, `complete!`, `schedule_next_email!`
- Verify: `bundle exec rspec spec/models/sequence_enrollment_spec.rb`

**4d. sequence_email_spec.rb**
- File: `spec/models/sequence_email_spec.rb`
- Test: associations, validations, scopes (`pending`, `due`), `mark_sent!`, `mark_failed!`
- Verify: `bundle exec rspec spec/models/sequence_email_spec.rb`

---

#### Step 5: Enrollment Service

- File: `app/services/sequence_enrollment_service.rb`
- Initialize with `digest_subscription`
- Method `enroll_on_subscription!`:
  - Find enabled sequences with `subscriber_joined` trigger for subscription's site
  - For each, create enrollment and schedule first step email
  - Skip if already enrolled (use `find_or_create_by` with unique constraint)
- Method `enroll_on_referral_milestone!(milestone)`:
  - Find enabled sequences with `referral_milestone` trigger matching milestone in `trigger_config`
  - Enroll and schedule first step
- Private method `create_enrollment(sequence)`:
  - Create `SequenceEnrollment` with status `:active`, `enrolled_at: Time.current`
  - Schedule first step email: `SequenceEmail.create!(enrollment:, email_step: sequence.email_steps.ordered.first, scheduled_for: Time.current + step.delay_seconds)`
- Verify: Service instantiates in console

---

#### Step 6: Trigger Integration

**6a. DigestSubscription callback**
- File: `app/models/digest_subscription.rb`
- Add: `after_create_commit :enroll_in_sequences`
- Private method: `def enroll_in_sequences; SequenceEnrollmentService.new(self).enroll_on_subscription!; end`
- Verify: Creating a subscription enrolls it in matching sequences

**6b. ReferralRewardService integration**
- File: `app/services/referral_reward_service.rb`
- In `check_and_award!`, after `send_reward_email(tier)`:
  - Add: `enroll_in_milestone_sequences(tier.milestone)`
- Private method: `def enroll_in_milestone_sequences(milestone); SequenceEnrollmentService.new(subscription).enroll_on_referral_milestone!(milestone); end`
- Verify: Awarding a tier enrolls in matching sequences

---

#### Step 7: Mailer

**7a. SequenceMailer**
- File: `app/mailers/sequence_mailer.rb`
- Method: `step_email(sequence_email)`
- Set `@sequence_email`, `@step`, `@enrollment`, `@subscription`, `@user`, `@site`, `@tenant`
- Return `nil` (early return) if `!@subscription.active?`
- Use `mailer_from_address` method (copy from `DigestMailer`)
- Subject: `@step.subject`
- Verify: Mailer can be instantiated

**7b. Mailer views**
- File: `app/views/sequence_mailer/step_email.html.erb`
- Use `@step.body_html` as main content
- Include unsubscribe link using `@subscription.unsubscribe_token`
- File: `app/views/sequence_mailer/step_email.text.erb`
- Use `@step.body_text` as main content
- Verify: Views render without errors

---

#### Step 8: Processing Job

- File: `app/jobs/process_sequence_enrollments_job.rb`
- `queue_as :default`
- `BATCH_SIZE = 100`
- `perform`:
  - `SequenceEmail.pending.due.includes(sequence_enrollment: { email_sequence: :site, digest_subscription: :user }).find_each(batch_size: BATCH_SIZE)`
  - For each `sequence_email`:
    - Wrap in `ActsAsTenant.with_tenant(sequence_email.sequence_enrollment.email_sequence.site.tenant)`
    - Check subscription active; if not, mark enrollment stopped and skip
    - Send `SequenceMailer.step_email(sequence_email).deliver_later`
    - Mark `sequence_email.mark_sent!`
    - Schedule next step via `sequence_email.sequence_enrollment.schedule_next_email!`
  - Rescue errors: log, `sequence_email.mark_failed!`, continue to next
- Verify: Job runs without errors in console

---

#### Step 9: Job Spec

- File: `spec/jobs/process_sequence_enrollments_job_spec.rb`
- Test: sends due emails (with `have_enqueued_mail`)
- Test: skips future emails
- Test: stops enrollment if subscription inactive
- Test: schedules next step after send
- Test: marks email failed on error, continues to next
- Test: wraps in correct tenant context
- Verify: `bundle exec rspec spec/jobs/process_sequence_enrollments_job_spec.rb`

---

#### Step 10: Mailer Spec

- File: `spec/mailers/sequence_mailer_spec.rb`
- Test: sends with correct subject from step
- Test: includes unsubscribe link
- Test: uses correct from address (site→tenant→default cascade)
- Test: returns nil if subscription inactive
- Test: body contains step content
- Verify: `bundle exec rspec spec/mailers/sequence_mailer_spec.rb`

---

#### Step 11: Admin Routes

- File: `config/routes.rb`
- Add within `namespace :admin` block (after `resources :referral_reward_tiers`):
```ruby
resources :email_sequences do
  member do
    post :enable
    post :disable
  end
  resources :email_steps, except: [:index]
end
```
- Verify: `rails routes | grep email_sequences` shows expected routes

---

#### Step 12: Admin Controllers

**12a. EmailSequencesController**
- File: `app/controllers/admin/email_sequences_controller.rb`
- Include `AdminAccess`
- `before_action :set_sequence, only: [:show, :edit, :update, :destroy, :enable, :disable]`
- CRUD actions: index, show, new, create, edit, update, destroy
- Custom actions: `enable` (set `enabled: true`), `disable` (set `enabled: false`)
- Strong params: `name`, `trigger_type`, `trigger_config`, `enabled`
- Parse `trigger_config` JSON in `tap` block (same pattern as referral tiers)
- Verify: Controller loads without syntax errors

**12b. EmailStepsController**
- File: `app/controllers/admin/email_steps_controller.rb`
- Include `AdminAccess`
- `before_action :set_sequence`
- `before_action :set_step, only: [:show, :edit, :update, :destroy]`
- CRUD actions: show, new, create, edit, update, destroy
- Strong params: `position`, `delay_seconds`, `subject`, `body_html`, `body_text`
- Verify: Controller loads without syntax errors

---

#### Step 13: Admin Views

**13a. Email Sequences views**
- `app/views/admin/email_sequences/index.html.erb` - Table with name, trigger type, enabled badge, step count, enrollment count, actions
- `app/views/admin/email_sequences/show.html.erb` - Sequence details, enable/disable button, steps timeline, add step button
- `app/views/admin/email_sequences/new.html.erb` - Render form partial
- `app/views/admin/email_sequences/edit.html.erb` - Render form partial
- `app/views/admin/email_sequences/_form.html.erb` - Form for name, trigger_type (select), trigger_config (JSON textarea)
- Verify: Index view renders

**13b. Email Steps views**
- `app/views/admin/email_steps/show.html.erb` - Step details, email preview
- `app/views/admin/email_steps/new.html.erb` - Render form partial
- `app/views/admin/email_steps/edit.html.erb` - Render form partial
- `app/views/admin/email_steps/_form.html.erb` - Form for position, delay_seconds, subject, body_html (textarea), body_text (textarea)
- Verify: Step form renders

---

#### Step 14: Admin Request Specs

**14a. email_sequences_spec.rb**
- File: `spec/requests/admin/email_sequences_spec.rb`
- Pattern: Mirror `spec/requests/admin/referral_reward_tiers_spec.rb`
- Test: authentication/authorization (not signed in, regular user, admin, tenant owner)
- Test: index lists sequences, tenant isolation
- Test: show displays sequence
- Test: create with valid/invalid params
- Test: update with valid/invalid params
- Test: destroy
- Test: enable/disable actions
- Verify: `bundle exec rspec spec/requests/admin/email_sequences_spec.rb`

**14b. email_steps_spec.rb**
- File: `spec/requests/admin/email_steps_spec.rb`
- Test: authentication/authorization
- Test: show displays step
- Test: create nested under sequence
- Test: update
- Test: destroy
- Verify: `bundle exec rspec spec/requests/admin/email_steps_spec.rb`

---

#### Step 15: i18n Keys

- File: `config/locales/en.yml`
- Add under `admin`:
```yaml
email_sequences:
  title: Email Sequences
  description: Automated email sequences for subscriber lifecycle
  created: Email sequence created successfully.
  updated: Email sequence updated successfully.
  deleted: Email sequence deleted successfully.
  enabled: Email sequence has been enabled.
  disabled: Email sequence has been disabled.
  no_sequences: No email sequences configured yet.
  create_first: Create your first email sequence
  new: New Email Sequence
  edit: Edit Email Sequence
  back_to_list: Back to Email Sequences
  trigger_types:
    subscriber_joined: New Subscriber
    referral_milestone: Referral Milestone
  form:
    name: Name
    trigger_type: Trigger
    trigger_config: Trigger Configuration (JSON)
    trigger_config_help: 'JSON object with trigger settings. Example: {"milestone": 3}'
    enabled: Enabled
    cancel: Cancel
    errors: Please fix the following errors
  table:
    name: Name
    trigger: Trigger
    steps: Steps
    enrollments: Enrollments
    status: Status
    actions: Actions
  show:
    steps_section: Email Steps
    add_step: Add Step
    no_steps: No steps defined yet.
email_steps:
  created: Email step created successfully.
  updated: Email step updated successfully.
  deleted: Email step deleted successfully.
  new: New Email Step
  edit: Edit Email Step
  back_to_sequence: Back to Sequence
  form:
    position: Position
    position_help: Order in sequence (0 = first)
    delay_seconds: Delay (seconds)
    delay_help: Time to wait before sending (0 = immediately)
    subject: Subject
    body_html: HTML Body
    body_text: Plain Text Body
    cancel: Cancel
    errors: Please fix the following errors
```
- Verify: i18n keys resolve in console

---

#### Step 16: Service Spec

- File: `spec/services/sequence_enrollment_service_spec.rb`
- Test: `enroll_on_subscription!` enrolls in matching enabled sequences
- Test: skips disabled sequences
- Test: skips if already enrolled
- Test: schedules first step email
- Test: `enroll_on_referral_milestone!` enrolls in matching milestone sequences
- Test: handles no matching sequences gracefully
- Verify: `bundle exec rspec spec/services/sequence_enrollment_service_spec.rb`

---

### Checkpoints

| After Step | Verify |
|------------|--------|
| Step 1 | `rails db:migrate && rails db:rollback STEP=4 && rails db:migrate` |
| Step 4 | `bundle exec rspec spec/models/email_*_spec.rb spec/models/sequence_*_spec.rb` |
| Step 6 | Manual: create subscription, verify enrollment created |
| Step 10 | `bundle exec rspec spec/mailers/sequence_mailer_spec.rb spec/jobs/process_sequence_enrollments_job_spec.rb` |
| Step 14 | `bundle exec rspec spec/requests/admin/email_*_spec.rb` |
| Step 16 | Full test suite: `bundle exec rspec --exclude-pattern "spec/{performance,system}/**/*_spec.rb"` |

### Test Plan

- [ ] Unit: Model validations, associations, enums, scopes, methods
- [ ] Unit: Service enrollment logic, edge cases
- [ ] Integration: Job processes emails, schedules next steps
- [ ] Integration: Mailer sends with correct content and from address
- [ ] Request: Admin CRUD operations with authorization
- [ ] Request: Tenant isolation for sequences
- [ ] Manual: End-to-end sequence flow (subscribe → enroll → process → send)

### Docs to Update

- [ ] None required (internal admin feature)

---

## Work Log

### 2026-01-30 - Planning Complete

**Gap Analysis:**
- All 4 models, migrations, factories, specs: none exist (create from scratch)
- SiteScoped pattern: exists in `Referral` model, replicate
- Trigger integration points: `DigestSubscription` (no existing callbacks except token generation), `ReferralRewardService.check_and_award!`
- Admin controller pattern: exists in `ReferralRewardTiersController`, replicate
- Request spec pattern: exists in `referral_reward_tiers_spec.rb`, replicate

**Codebase Patterns Verified:**
- Multi-tenant wrapping: `ActsAsTenant.with_tenant(subscription.site.tenant)` per record
- Batch processing: `find_each(batch_size: 100)`
- From-address cascade: `site.setting("email.from_address") || tenant.setting("email.from_address") || default`
- Mailer early return: Return `nil` if no content/inactive subscription
- Admin authorization: `include AdminAccess` concern
- Test setup: `setup_tenant_context(tenant)`, `host! tenant.hostname`

**Plan Summary:**
- Steps: 16 (broken into sub-steps: ~28 total)
- Risks: 5 identified with mitigations
- Checkpoints: 6 verification points
- Test coverage: extensive (model, service, job, mailer, request specs)

**Files to Create:** ~30
**Files to Modify:** 4 (`digest_subscription.rb`, `referral_reward_service.rb`, `routes.rb`, `en.yml`)

---

### 2026-01-30 16:05 - Triage Complete

Quality gates:
- Lint: `bundle exec rubocop --format progress` + `bundle exec erb_lint app/views/`
- Types: N/A (Ruby)
- Tests: `bundle exec rspec --exclude-pattern "spec/{performance,system}/**/*_spec.rb"`
- Build: `npm run build && npm run build:css && bundle exec rails assets:precompile`

Task validation:
- Context: clear - background, competitive context, user value, RICE score all defined
- Criteria: specific - 25 testable acceptance criteria with clear file/model definitions
- Dependencies: satisfied - referral program (002-001) completed, existing infrastructure verified (DigestSubscription, ReferralRewardService)

Complexity:
- Files: many (~30 new files: 4 migrations, 4 models, 4 factories, 4 model specs, 1 service, 1 service spec, 1 mailer, 1 mailer spec, 1 job, 1 job spec, 2 controllers, 2 request specs, ~8 views + modifications to 4 existing files)
- Risk: medium (integrates with existing DigestSubscription and ReferralRewardService, multi-tenant aware)

Ready: yes

---

### 2026-01-30 16:30 - Task Expanded

- Intent: BUILD
- Scope: Email automation sequences with subscriber_joined and referral_milestone triggers
- Key files to create:
  - 4 migrations (email_sequences, email_steps, sequence_enrollments, sequence_emails)
  - 4 models (EmailSequence, EmailStep, SequenceEnrollment, SequenceEmail)
  - 1 service (SequenceEnrollmentService)
  - 1 mailer (SequenceMailer)
  - 1 job (ProcessSequenceEnrollmentsJob)
  - 2 admin controllers (EmailSequencesController, EmailStepsController)
  - Admin views for sequence/step management
- Files to modify:
  - `app/models/digest_subscription.rb` (add enrollment trigger)
  - `app/services/referral_reward_service.rb` (add milestone enrollment)
  - `config/routes.rb` (add admin routes)
  - `config/locales/en.yml` (add i18n keys)
- Complexity: Medium-High (16 steps, multiple models, integration points)
- Dependencies: None (builds on existing infrastructure)

---

### 2026-01-30 16:45 - Implementation Complete

**Files Created:**
- `db/migrate/20260130161100_create_email_sequences.rb`
- `db/migrate/20260130161101_create_email_steps.rb`
- `db/migrate/20260130161102_create_sequence_enrollments.rb`
- `db/migrate/20260130161103_create_sequence_emails.rb`
- `app/models/email_sequence.rb`
- `app/models/email_step.rb`
- `app/models/sequence_enrollment.rb`
- `app/models/sequence_email.rb`
- `app/services/sequence_enrollment_service.rb`
- `app/mailers/sequence_mailer.rb`
- `app/views/sequence_mailer/step_email.html.erb`
- `app/views/sequence_mailer/step_email.text.erb`
- `app/jobs/process_sequence_enrollments_job.rb`
- `app/controllers/admin/email_sequences_controller.rb`
- `app/controllers/admin/email_steps_controller.rb`
- `app/views/admin/email_sequences/index.html.erb`
- `app/views/admin/email_sequences/show.html.erb`
- `app/views/admin/email_sequences/new.html.erb`
- `app/views/admin/email_sequences/edit.html.erb`
- `app/views/admin/email_sequences/_form.html.erb`
- `app/views/admin/email_steps/show.html.erb`
- `app/views/admin/email_steps/new.html.erb`
- `app/views/admin/email_steps/edit.html.erb`
- `app/views/admin/email_steps/_form.html.erb`
- `spec/factories/email_sequences.rb`
- `spec/factories/email_steps.rb`
- `spec/factories/sequence_enrollments.rb`
- `spec/factories/sequence_emails.rb`

**Files Modified:**
- `app/models/digest_subscription.rb` - Added `sequence_enrollments` association and `after_create_commit :enroll_in_sequences` callback
- `app/services/referral_reward_service.rb` - Added `enroll_in_milestone_sequences` integration
- `config/routes.rb` - Added admin routes for email_sequences and email_steps
- `config/locales/en.yml` - Added i18n keys for admin.email_sequences, admin.email_steps, and sequence_mailer

**Quality Gates:**
- Rubocop: Pass (426 files inspected, no offenses)
- ERB Lint: Pass (141 files, no errors)
- Migrations: Verified with rollback and re-migrate

---

## Testing Evidence

_Tests to be added in next phase (Step 4, 9, 10, 14, 16)_

---

## Notes

**In Scope:**
- EmailSequence, EmailStep, SequenceEnrollment, SequenceEmail models
- Trigger types: `subscriber_joined`, `referral_milestone`
- Processing job to send due emails
- Admin CRUD for sequences and steps
- Integration with DigestSubscription (enrollment trigger)
- Integration with ReferralRewardService (milestone trigger)

**Out of Scope (future tasks):**
- Visual drag-and-drop sequence builder (keeping it simple with forms)
- Open/click tracking (requires email analytics infrastructure)
- Conditional logic/branching in sequences
- A/B testing variants
- Pre-built sequence templates (can be added via seeds later)
- Trigger types: `inactivity`, `days_since_joined` (Phase 2)
- Re-engagement sequences (requires inactivity tracking)
- Email content editor with WYSIWYG (using textarea for now)

**Assumptions:**
- One subscriber can be enrolled in multiple sequences (different triggers)
- A subscriber cannot be enrolled twice in the same sequence
- Unsubscribing stops all active enrollments
- Sequences can be enabled/disabled (disabled sequences don't enroll new subscribers)
- Existing enrollments continue even if sequence is disabled
- Delay is measured from enrollment time (step 1) or previous step send time (steps 2+)

**Edge Cases:**
| Case | Handling |
|------|----------|
| Subscriber unsubscribes mid-sequence | Mark enrollment as `stopped`, don't send remaining emails |
| Sequence disabled mid-enrollment | Continue sending remaining emails (existing enrollments honored) |
| Email step deleted mid-enrollment | Skip to next step (or complete if last) |
| Sequence deleted | Cascade delete enrollments (or nullify if we want history) |
| Subscriber re-subscribes | New enrollment starts fresh (previous enrollment stays stopped) |
| Multiple sequences with same trigger | Enroll in all matching enabled sequences |

**Risks:**
| Risk | Mitigation |
|------|------------|
| Email flooding on mass signup | Batch processing (100 at a time), rate limiting can be added later |
| Orphaned enrollments from deleted sequences | Use dependent: :destroy on associations |
| Performance with many enrollments | Index on (status, scheduled_for), batch processing |
| Timezone issues with delays | Store all times in UTC, delay is relative (seconds) |

**Technical Decisions:**
- Using `delay_seconds` (integer) instead of `delay_days` for flexibility (can support hours, minutes)
- Using `trigger_config` JSONB for trigger-specific settings (e.g., milestone threshold for referral_milestone)
- Storing `body_html` and `body_text` separately (not computing text from HTML)
- Single job processes all sites (uses `ActsAsTenant.with_tenant` per enrollment)

---

## Links

- Research: Kit automation templates, Substack automation rollout
- Related: DigestSubscription, SendDigestEmailsJob
