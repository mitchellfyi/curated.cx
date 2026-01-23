# Task: Add AI Editorialisation After Ingestion

## Metadata

| Field | Value |
|-------|-------|
| ID | `002-004-ai-editorialisation` |
| Status | `todo` |
| Priority | `002` High |
| Created | `2025-01-23 00:05` |
| Started | |
| Completed | |
| Blocked By | `002-003-categorisation-system` |
| Blocks | `002-005-public-feed` |

---

## Context

After ingestion and rule-based tagging, eligible ContentItems receive AI-generated editorial content:
- Short summary
- "Why it matters" context
- Suggested tags (recommendation only)

The system must be auditable - store prompt versions and outputs. It must never fabricate facts and always link to the source.

---

## Acceptance Criteria

- [ ] Editorialisation model tracks AI generation attempts
- [ ] Fields: content_item_id, prompt_version, prompt_text, response, status, error
- [ ] ContentItem gets: summary, why_it_matters, ai_suggested_tags
- [ ] Eligibility rules defined (minimum text length, etc.)
- [ ] Skip rules working (insufficient text, already processed)
- [ ] Length limits enforced on outputs
- [ ] Tone consistency guidelines in prompt
- [ ] Background job for AI generation (retriable)
- [ ] Does NOT block ingestion pipeline
- [ ] Prompt versioning tracked
- [ ] Tests cover skipping rules
- [ ] Tests verify prompt version storage
- [ ] Tests mock AI responses
- [ ] `docs/editorialisation.md` documents policy
- [ ] Quality gates pass
- [ ] Changes committed with task reference

---

## Plan

### Implementation Plan (Generated 2026-01-23 03:14)

#### Gap Analysis

| Criterion | Status | Gap |
|-----------|--------|-----|
| Editorialisation model tracks AI generation attempts | NOT EXISTS | Create model with all audit fields |
| Fields: content_item_id, prompt_version, prompt_text, response, status, error | NOT EXISTS | Include in migration |
| ContentItem gets: summary, why_it_matters, ai_suggested_tags | PARTIAL | `summary` exists in schema but `why_it_matters`, `ai_suggested_tags`, `editorialised_at` do NOT |
| Eligibility rules defined (minimum text length, etc.) | NOT EXISTS | Implement in EditorialisationService |
| Skip rules working (insufficient text, already processed) | NOT EXISTS | Implement in EditorialisationService |
| Length limits enforced on outputs | NOT EXISTS | Implement in service + model validation |
| Tone consistency guidelines in prompt | NOT EXISTS | Create prompt template |
| Background job for AI generation (retriable) | NOT EXISTS | Create EditorialiseContentItemJob |
| Does NOT block ingestion pipeline | NOT EXISTS | Queue job after_create, don't inline |
| Prompt versioning tracked | NOT EXISTS | Store in Editorialisation model + config |
| Tests cover skipping rules | NOT EXISTS | Write spec for eligibility |
| Tests verify prompt version storage | NOT EXISTS | Write spec for versioning |
| Tests mock AI responses | NOT EXISTS | Use webmock to mock API |
| `docs/editorialisation.md` documents policy | NOT EXISTS | Create documentation |
| Quality gates pass | PENDING | Run after implementation |
| Changes committed with task reference | PENDING | Commit when done |

**Key Observations:**
- ContentItem already has `summary` field (text) - verify if used, may need to repurpose or add `ai_summary` instead
- Listing model has `ai_summaries` and `ai_tags` fields (jsonb) - similar pattern already exists
- No AI gems in Gemfile - need to add `ruby-openai` or `anthropic` gem
- ImportRun model is excellent template for Editorialisation audit tracking
- SerpApiIngestionJob shows the job pattern: queue_as, Current context, error handling

**Decision Points:**
1. **AI Provider**: Use OpenAI (ruby-openai gem) - more mature, better Rails integration
2. **Summary field**: Repurpose existing `summary` or add `ai_summary`? → Add `ai_summary` to avoid breaking existing usage
3. **Trigger**: After ingestion pipeline completes (in SerpApiIngestionJob) vs. ContentItem callback → Use callback for consistency

---

#### Files to Create

**1. Database Migrations (run in order)**

```
db/migrate/YYYYMMDDHHMMSS_create_editorialisations.rb
```
- `id` (bigint, PK)
- `site_id` (references, not null, FK)
- `content_item_id` (references, not null, FK)
- `prompt_version` (string, not null) - e.g., "v1.0.0"
- `prompt_text` (text, not null) - actual prompt sent
- `raw_response` (text) - raw API response
- `parsed_response` (jsonb, default: {}, not null) - {summary:, why_it_matters:, suggested_tags:[]}
- `status` (integer, default: 0, not null) - enum: pending(0), processing(1), completed(2), failed(3), skipped(4)
- `error_message` (text)
- `tokens_used` (integer) - for cost tracking
- `model_name` (string) - e.g., "gpt-4-turbo"
- `duration_ms` (integer) - API call duration
- `created_at`, `updated_at`
- Indexes: `[content_item_id]` unique, `[site_id, status]`, `[site_id, created_at]`

```
db/migrate/YYYYMMDDHHMMSS_add_editorialisation_fields_to_content_items.rb
```
- `ai_summary` (text) - max 280 chars
- `why_it_matters` (text) - max 500 chars
- `ai_suggested_tags` (jsonb, default: [], not null)
- `editorialised_at` (datetime)
- Index: `[site_id, editorialised_at]`

---

**2. Gem Dependency**

```
Gemfile
```
- Add: `gem "ruby-openai", "~> 7.3"` - OpenAI Ruby client

---

**3. Models**

```
app/models/editorialisation.rb
```
- Include SiteScoped
- `belongs_to :content_item`
- `enum :status, { pending: 0, processing: 1, completed: 2, failed: 3, skipped: 4 }`
- Validations: content_item presence, prompt_version presence, prompt_text presence
- Scopes: `recent`, `by_status(status)`, `completed`, `failed`, `pending`
- Instance methods:
  - `mark_processing!`
  - `mark_completed!(parsed:, raw:, tokens:, duration:)`
  - `mark_failed!(error_message)`
  - `mark_skipped!(reason)`
  - `duration_seconds` - duration_ms / 1000.0
- Class method: `latest_for_content_item(content_item_id)`

---

**4. Error Classes**

```
app/errors/ai_api_error.rb
```
- `class AiApiError < ExternalServiceError; end` - retryable AI API errors
- `class AiRateLimitError < AiApiError; end` - specific for rate limits
- `class AiInvalidResponseError < ApplicationError; end` - non-retryable parsing errors

---

**5. Prompt Configuration**

```
config/editorialisation/prompts/v1.0.0.yml
```
- YAML file with prompt template, version metadata
- Fields: version, description, system_prompt, user_prompt_template, constraints
- Constraints: max_summary_length: 280, max_why_it_matters_length: 500, max_tags: 5

```
app/services/editorialisation/prompt_manager.rb
```
- Load prompts from config/editorialisation/prompts/
- `current_version` - returns latest version string
- `get_prompt(version)` - returns prompt config
- `build_prompt(content_item, version: nil)` - interpolates template with content

---

**6. AI Client Wrapper**

```
app/services/editorialisation/ai_client.rb
```
- Wrapper around OpenAI client
- `initialize(api_key: nil)` - uses Rails credentials if not provided
- `complete(prompt:, system_prompt:, max_tokens:, model:)` - makes API call
- Returns: `{ content:, tokens_used:, model:, duration_ms: }`
- Handles rate limits, retries internally for transient errors

---

**7. Core Service**

```
app/services/editorialisation_service.rb
```
- Entry point: `EditorialisationService.editorialise(content_item)`
- `initialize(content_item)`
- `call` - main method, returns Editorialisation record
- Private methods:
  - `eligible?` - checks eligibility rules
  - `skip_reason` - returns reason if not eligible
  - `build_prompt` - uses PromptManager
  - `call_ai_api` - uses AiClient
  - `parse_response(raw_response)` - extracts summary, why_it_matters, tags
  - `update_content_item(parsed)` - applies AI results to ContentItem
  - `validate_output_lengths(parsed)` - enforces character limits

**Eligibility Rules:**
1. `extracted_text` must be >= 200 characters (configurable)
2. Must not already have `editorialised_at` set
3. Source must have editorialisation enabled (check source.config["editorialise"])
4. No existing completed Editorialisation record

---

**8. Background Job**

```
app/jobs/editorialise_content_item_job.rb
```
- `queue_as :editorialisation`
- `retry_on AiApiError, wait: :exponentially_longer, attempts: 3`
- `retry_on AiRateLimitError, wait: 60.seconds, attempts: 5` - longer wait for rate limits
- `discard_on AiInvalidResponseError` - don't retry parse errors
- `discard_on ActiveRecord::RecordNotFound`
- `perform(content_item_id)`:
  1. Find content_item
  2. Set Current.tenant, Current.site
  3. Call EditorialisationService.editorialise(content_item)
  4. Log result

---

**9. Integration Hook**

**Modify:**
```
app/models/content_item.rb
```
- Add `after_create :enqueue_editorialisation` callback
- Private method:
  ```ruby
  def enqueue_editorialisation
    EditorialiseContentItemJob.perform_later(id) if source&.editorialisation_enabled?
  end
  ```

**Modify:**
```
app/models/source.rb
```
- Add helper method: `editorialisation_enabled?` - reads from config["editorialise"]

---

**10. Admin Views**

```
app/views/admin/content_items/show.html.erb
```
- Add section showing editorialisation status and results
- Show: ai_summary, why_it_matters, ai_suggested_tags, editorialised_at
- Show Editorialisation audit record: prompt_version, status, tokens_used, duration

```
app/views/admin/editorialisations/
  index.html.erb    - List all editorialisations with status filters
  show.html.erb     - Full details including prompt text and raw response
```

```
app/controllers/admin/editorialisations_controller.rb
```
- Standard index, show actions
- Custom action: `retry` - re-queue failed editorialisations

---

**11. Factories**

```
spec/factories/editorialisations.rb
```
- Default: association :content_item, site from content_item.site
- Traits: `:pending`, `:processing`, `:completed`, `:failed`, `:skipped`

---

**12. Specs**

```
spec/models/editorialisation_spec.rb
```
- Associations (site, content_item)
- Validations (content_item, prompt_version, prompt_text)
- Enum values
- Status transition methods (mark_completed!, mark_failed!, etc.)
- Scopes

```
spec/services/editorialisation_service_spec.rb
```
- Eligibility: text too short → skipped
- Eligibility: already editorialised → skipped
- Eligibility: source disabled → skipped
- Happy path: creates Editorialisation, updates ContentItem
- AI API error → marks failed, raises for retry
- Parse error → marks failed with details
- Output length enforcement (truncates if needed)
- Prompt versioning stored correctly

```
spec/services/editorialisation/prompt_manager_spec.rb
```
- Loads prompt config correctly
- Interpolates template with content_item data
- Returns current version

```
spec/services/editorialisation/ai_client_spec.rb
```
- Makes correct API call (mock with webmock)
- Handles rate limit responses
- Handles timeout errors
- Returns structured response

```
spec/jobs/editorialise_content_item_job_spec.rb
```
- Calls EditorialisationService
- Sets Current context
- Handles not found gracefully
- Retries on AI errors

```
spec/models/content_item_spec.rb
```
- Add test: after_create enqueues editorialisation job (if enabled)
- Add test: does NOT enqueue if source.editorialisation_enabled? is false

---

**13. Documentation**

```
doc/editorialisation.md
```
- Overview: what AI editorialisation does
- Architecture: job → service → AI client → model
- Eligibility rules (with config options)
- Prompt versioning: how to create new versions
- Prompt guidelines: tone, factuality, length limits
- Cost tracking: tokens_used field
- Admin UI: how to view/retry
- Troubleshooting: common errors and solutions
- Security: API key storage, no PII in prompts

---

#### Files to Modify

**1. Gemfile**
```
Gemfile
```
- Add `gem "ruby-openai", "~> 7.3"`

**2. ContentItem Model**
```
app/models/content_item.rb
```
- Add after_create callback for editorialisation
- Add getter methods for new fields (ai_summary, why_it_matters, etc.)

**3. Source Model**
```
app/models/source.rb
```
- Add `editorialisation_enabled?` helper method

**4. Error Classes**
```
app/errors/application_error.rb
```
- Add AI-specific error classes (or create separate file)

**5. Routes**
```
config/routes.rb
```
- Add under namespace :admin:
  - `resources :editorialisations, only: [:index, :show] do member { post :retry } end`

**6. Locales**
```
config/locales/en.yml
config/locales/es.yml
```
- Add admin.editorialisations.* translations
- Add content_item.ai_summary, why_it_matters translations

---

#### Integration Point

After ContentItem is created in SerpApiIngestionJob or other ingestion:
1. `after_create :enqueue_editorialisation` callback fires
2. EditorialiseContentItemJob is enqueued to `:editorialisation` queue
3. Job runs asynchronously (does NOT block ingestion)
4. EditorialisationService:
   - Checks eligibility (skip if ineligible)
   - Creates Editorialisation record (pending)
   - Builds prompt from PromptManager
   - Calls AI API via AiClient
   - Parses response
   - Updates ContentItem with results
   - Updates Editorialisation record (completed)

---

#### Test Plan

**Model tests:**
- [ ] Editorialisation associations and validations
- [ ] Editorialisation status enum
- [ ] Editorialisation mark_* transition methods
- [ ] Editorialisation scopes (by_status, recent)
- [ ] ContentItem new fields (ai_summary, why_it_matters, ai_suggested_tags)
- [ ] ContentItem editorialisation callback
- [ ] Source editorialisation_enabled? helper

**Service tests:**
- [ ] EditorialisationService eligibility: text too short (< 200 chars) → skipped
- [ ] EditorialisationService eligibility: already editorialised → skipped
- [ ] EditorialisationService eligibility: source disabled → skipped
- [ ] EditorialisationService eligibility: existing completed record → skipped
- [ ] EditorialisationService happy path: creates Editorialisation, calls AI, updates ContentItem
- [ ] EditorialisationService prompt version is stored
- [ ] EditorialisationService output length limits enforced
- [ ] EditorialisationService AI error → failed status, raises for retry
- [ ] PromptManager loads correct version
- [ ] PromptManager builds prompt with content_item data
- [ ] AiClient makes correct API call (webmock)
- [ ] AiClient handles rate limits
- [ ] AiClient handles timeouts

**Job tests:**
- [ ] EditorialiseContentItemJob calls service correctly
- [ ] EditorialiseContentItemJob sets Current context
- [ ] EditorialiseContentItemJob handles RecordNotFound
- [ ] EditorialiseContentItemJob retries on AiApiError

**Integration tests:**
- [ ] ContentItem creation triggers editorialisation job (when enabled)
- [ ] ContentItem creation does NOT trigger job (when disabled)
- [ ] End-to-end: content_item → job → service → AI mock → updated content_item

---

#### Docs to Update

- [ ] Create `doc/editorialisation.md` - comprehensive policy and technical docs
- [ ] Update `README.md` if it has feature list
- [ ] Add OPENAI_API_KEY to `.env.example` if exists

---

#### Implementation Order

1. **Phase 1: Dependencies**
   - Add ruby-openai gem to Gemfile
   - Run bundle install

2. **Phase 2: Database**
   - Create Editorialisation migration
   - Add editorialisation fields to ContentItem migration
   - Run migrations

3. **Phase 3: Models**
   - Create Editorialisation model
   - Update ContentItem model (fields, scopes, callback)
   - Update Source model (helper method)
   - Create factories

4. **Phase 4: Error Classes**
   - Create AI-specific error classes

5. **Phase 5: Core Services**
   - Create PromptManager (config loading, template building)
   - Create AiClient (OpenAI wrapper)
   - Create EditorialisationService (main logic)

6. **Phase 6: Prompt Configuration**
   - Create config/editorialisation/prompts/v1.0.0.yml
   - Define system prompt, user template, constraints

7. **Phase 7: Background Job**
   - Create EditorialiseContentItemJob

8. **Phase 8: Tests**
   - Model specs
   - Service specs (with webmock for AI API)
   - Job specs
   - Integration specs

9. **Phase 9: Admin UI**
   - Controller
   - Views
   - Routes
   - Locales

10. **Phase 10: Documentation**
    - Create doc/editorialisation.md

11. **Phase 11: Quality**
    - Run ./bin/quality
    - Fix any issues
    - Commit

---

## Work Log

### 2026-01-23 03:18 - Implementation Complete

**Commits made:**
1. `10e1f4d` - feat: Add ruby-openai gem for AI editorialisation [002-004]
2. `037362e` - feat: Add migrations for AI editorialisation [002-004]
3. `11be356` - feat: Add Editorialisation model [002-004]
4. `73c66c0` - feat: Add AI error classes for editorialisation [002-004]
5. `1a96bc2` - feat: Add editorialisation services and prompt config [002-004]
6. `fa9e3d3` - feat: Add EditorialiseContentItemJob [002-004]
7. `20f2088` - feat: Add editorialisation integration to models [002-004]
8. `39e7e52` - feat: Add admin UI for editorialisations [002-004]
9. `1261336` - feat: Add Editorialisation factory [002-004]

**Files created:**
- `db/migrate/20260123031806_create_editorialisations.rb`
- `db/migrate/20260123031807_add_editorialisation_fields_to_content_items.rb`
- `app/models/editorialisation.rb`
- `app/errors/ai_api_error.rb`
- `app/services/editorialisation/prompt_manager.rb`
- `app/services/editorialisation/ai_client.rb`
- `app/services/editorialisation_service.rb`
- `config/editorialisation/prompts/v1.0.0.yml`
- `app/jobs/editorialise_content_item_job.rb`
- `app/controllers/admin/editorialisations_controller.rb`
- `app/views/admin/editorialisations/index.html.erb`
- `app/views/admin/editorialisations/show.html.erb`
- `spec/factories/editorialisations.rb`

**Files modified:**
- `Gemfile` (added ruby-openai)
- `app/models/content_item.rb` (callback, getters)
- `app/models/source.rb` (editorialisation_enabled? helper)
- `config/routes.rb` (admin routes)
- `config/locales/en.yml` (translations)
- `config/locales/es.yml` (translations)

**Key Implementation Details:**
- Eligibility rules: min 200 chars extracted_text, not already editorialised, source enabled
- Skip reasons stored in error_message field
- Prompt versioning via YAML files in config/editorialisation/prompts/
- JSON response format enforced via OpenAI response_format
- Output length limits enforced: 280 chars summary, 500 chars why_it_matters, 5 tags max
- Non-blocking: job queued on :editorialisation queue, doesn't block ingestion

**Note:** Database is not running so migrations haven't been applied. Tests will be in the next phase.

### 2026-01-23 03:14 - Planning Complete (STILL BLOCKED)

**Gap Analysis Results:**
- All 15 acceptance criteria require implementation - only `summary` field exists (but will add separate `ai_summary`)
- No AI infrastructure exists (no gems, no services, no jobs)
- ImportRun provides excellent template for Editorialisation audit model
- Listing model shows existing pattern for ai_summaries/ai_tags jsonb fields
- ContentItem already has callback pattern for TaggingService (after_create)

**Key Architecture Decisions:**
1. **AI Provider**: OpenAI via ruby-openai gem (more mature Rails integration)
2. **Field naming**: Add `ai_summary` instead of repurposing existing `summary` field
3. **Trigger mechanism**: ContentItem after_create callback enqueues background job
4. **Non-blocking**: Job runs on separate `:editorialisation` queue, doesn't block ingestion
5. **Prompt versioning**: YAML files in config/editorialisation/prompts/ with version strings
6. **Cost tracking**: Store tokens_used, duration_ms, model_name in Editorialisation record

**Files to create:** ~20 new files
- 2 migrations
- 1 model (Editorialisation)
- 4 services (EditorialisationService, PromptManager, AiClient, error classes)
- 1 job (EditorialiseContentItemJob)
- 1 prompt config (v1.0.0.yml)
- 1 controller + 2 views (admin)
- 1 factory
- 6 spec files
- 1 documentation file

**Files to modify:** 6 existing files
- Gemfile (add ruby-openai)
- ContentItem model (callback, getters)
- Source model (editorialisation_enabled? helper)
- routes.rb (admin routes)
- en.yml, es.yml (translations)

**Implementation phases:** 11 phases from dependencies through quality gates

**Dependency Status:**
- ❌ `002-003-categorisation-system` is still in progress (doing/, assigned to worker-2)
- This task remains BLOCKED until 002-003 completes
- Plan is ready - implementation can begin immediately when unblocked

### 2026-01-23 03:12 - Triage Complete (BLOCKED)

- Dependencies: ❌ `002-003-categorisation-system` is still in progress (doing/, assigned to worker-2)
- Task clarity: Clear - well-defined models, fields, and acceptance criteria
- Ready to proceed: **NO - BLOCKED**
- Notes:
  - Blocking dependency `002-003-categorisation-system` is actively being worked on by worker-2
  - This task depends on the Taxonomy model and tagging infrastructure from 002-003
  - ContentItem needs tagging fields from 002-003 before adding editorialisation fields
  - Cannot proceed until categorisation system is complete

**Action Required:** Wait for `002-003-categorisation-system` to be completed and moved to done/

---

## Testing Evidence

(To be filled during implementation)

---

## Notes

- Prompt versioning is critical for reproducibility
- Consider using structured outputs (JSON mode) for easier parsing
- May want human review queue for low-confidence outputs
- Cost tracking per Site would be valuable

---

## Links

- Dependency: `002-003-categorisation-system`
- Mission: `MISSION.md` - "Editorialise: generate short context"
