# AI Editorialisation

AI editorialisation automatically generates editorial content for ContentItems after ingestion, providing summaries, context, and tag suggestions.

## Overview

When a ContentItem is created, the system can optionally generate:
- **AI Summary**: A concise summary (max 280 characters)
- **Why It Matters**: Context explaining relevance (max 500 characters)
- **Suggested Tags**: Up to 5 relevant topic tags for categorisation

This content is generated via OpenAI's API and stored for audit purposes.

## Architecture

```
ContentItem created
        |
        v
after_create callback
        |
        v
EditorialiseContentItemJob enqueued (queue: :editorialisation)
        |
        v
EditorialisationService.editorialise(content_item)
        |
        +-- Eligibility check (skip if ineligible)
        |
        +-- Create Editorialisation record (pending)
        |
        +-- PromptManager builds prompt from YAML template
        |
        +-- AiClient calls OpenAI API
        |
        +-- Parse JSON response
        |
        +-- Update ContentItem with results
        |
        v
Editorialisation record (completed/failed/skipped)
```

## Enabling Editorialisation

Editorialisation is enabled per-Source. Set the `editorialise` option in the Source's config:

```json
{
  "api_key": "...",
  "query": "...",
  "editorialise": true
}
```

When disabled (default), ContentItems from that Source skip editorialisation.

## Eligibility Rules

A ContentItem is eligible for editorialisation when ALL of these are true:

1. **Source enabled**: `source.config["editorialise"]` is truthy
2. **Sufficient text**: `extracted_text` has at least 200 characters
3. **Not already processed**: `editorialised_at` is nil
4. **No existing record**: No completed Editorialisation record exists

If ineligible, an Editorialisation record is created with `status: skipped` and the reason stored in `error_message`.

## Prompt Versioning

Prompts are stored as YAML files in `config/editorialisation/prompts/`:

```
config/editorialisation/prompts/
  v1.0.0.yml
  v1.1.0.yml  # future versions
```

Each prompt file contains:
- `version`: Version identifier (e.g., "v1.0.0")
- `description`: Human-readable description
- `constraints`: Output limits (max lengths, tag count)
- `model`: OpenAI model configuration (name, max_tokens, temperature)
- `system_prompt`: AI persona and behavior guidelines
- `user_prompt_template`: Template with placeholders for content

### Current Prompt (v1.0.0)

```yaml
version: "v1.0.0"
constraints:
  max_summary_length: 280
  max_why_it_matters_length: 500
  max_suggested_tags: 5
model:
  name: "gpt-4o-mini"
  max_tokens: 800
  temperature: 0.3
```

### Creating a New Prompt Version

1. Copy the latest prompt file with a new version number
2. Modify the prompt content as needed
3. Update version and description fields
4. The PromptManager automatically uses the latest version

All past prompts are preserved for reproducibility. The Editorialisation record stores both the `prompt_version` used and the full `prompt_text` sent.

## API Configuration

Set your OpenAI API key via Rails credentials or environment variable:

```bash
# Via credentials (preferred)
rails credentials:edit
# Add:
# openai:
#   api_key: sk-...

# Via environment variable
export OPENAI_API_KEY=sk-...
```

## Output Fields

### ContentItem Fields

| Field | Type | Max Length | Description |
|-------|------|------------|-------------|
| `ai_summary` | text | 280 chars | Concise content summary |
| `why_it_matters` | text | 500 chars | Context and relevance |
| `ai_suggested_tags` | jsonb | 5 items | Array of suggested tags |
| `editorialised_at` | datetime | - | Timestamp of processing |

### Editorialisation Record (Audit)

| Field | Type | Description |
|-------|------|-------------|
| `content_item_id` | integer | Foreign key to ContentItem |
| `site_id` | integer | Foreign key to Site |
| `prompt_version` | string | Version used (e.g., "v1.0.0") |
| `prompt_text` | text | Exact prompt sent to API |
| `raw_response` | text | Raw API response |
| `parsed_response` | jsonb | Parsed {summary, why_it_matters, suggested_tags} |
| `status` | enum | pending, processing, completed, failed, skipped |
| `error_message` | text | Error details (if failed/skipped) |
| `tokens_used` | integer | API token consumption |
| `model_name` | string | Model used (e.g., "gpt-4o-mini") |
| `duration_ms` | integer | API call duration |

## Error Handling

### Error Classes

| Error | Retryable | Description |
|-------|-----------|-------------|
| `AiApiError` | Yes | Transient API failures (network, server errors) |
| `AiRateLimitError` | Yes | Rate limit exceeded (60s wait between retries) |
| `AiTimeoutError` | Yes | API call timed out |
| `AiInvalidResponseError` | No | Malformed or unparseable response |
| `AiConfigurationError` | No | Missing API key or bad config |

### Retry Behavior

```ruby
retry_on AiApiError, wait: :exponentially_longer, attempts: 3
retry_on AiTimeoutError, wait: :exponentially_longer, attempts: 3
retry_on AiRateLimitError, wait: 60.seconds, attempts: 5
discard_on AiInvalidResponseError
discard_on AiConfigurationError
```

Failed editorialisations are marked with `status: failed` and the error message is stored.

## Admin Interface

### Viewing Editorialisations

Navigate to **Admin > Editorialisations** to:
- View all editorialisation attempts with status filters
- Inspect individual records including full prompt and response
- Retry failed editorialisations

### ContentItem Detail

The ContentItem show page displays:
- AI summary and "why it matters" text
- Suggested tags
- Editorialisation status and metadata
- Link to the audit record

## Cost Tracking

The `tokens_used` field tracks API consumption for cost monitoring. Aggregate across Sites or time periods:

```ruby
# Total tokens used by a site this month
Editorialisation.where(site: site)
  .where(created_at: Time.current.beginning_of_month..)
  .sum(:tokens_used)
```

## Files

| File | Purpose |
|------|---------|
| `app/models/editorialisation.rb` | Audit record model |
| `app/services/editorialisation_service.rb` | Main orchestration |
| `app/services/editorialisation/prompt_manager.rb` | Prompt loading and building |
| `app/services/editorialisation/ai_client.rb` | OpenAI API wrapper |
| `app/jobs/editorialise_content_item_job.rb` | Background job |
| `app/errors/ai_api_error.rb` | AI-specific error classes |
| `config/editorialisation/prompts/v1.0.0.yml` | Prompt template |
| `app/controllers/admin/editorialisations_controller.rb` | Admin UI |
| `app/views/admin/editorialisations/` | Admin views |

## Testing

```bash
# Run all editorialisation specs
bundle exec rspec spec/models/editorialisation_spec.rb
bundle exec rspec spec/services/editorialisation_service_spec.rb
bundle exec rspec spec/services/editorialisation/prompt_manager_spec.rb
bundle exec rspec spec/services/editorialisation/ai_client_spec.rb
bundle exec rspec spec/jobs/editorialise_content_item_job_spec.rb
```

AI API calls are mocked using WebMock in specs.

## Troubleshooting

### Content Not Being Editorialised

1. Check if Source has `editorialise: true` in config
2. Verify ContentItem has sufficient `extracted_text` (200+ chars)
3. Check for existing completed Editorialisation record
4. Verify API key is configured

### Failed Editorialisations

1. Check the `error_message` field for details
2. For rate limits, wait and retry will happen automatically
3. For configuration errors, check API key setup
4. For parse errors, review the `raw_response` for API issues

### Viewing API Responses

Navigate to **Admin > Editorialisations > [record]** to see:
- Full `prompt_text` sent to API
- Complete `raw_response` received
- `parsed_response` after extraction
