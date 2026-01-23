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

1. **Create Editorialisation model**
   - Fields: content_item_id, prompt_version, prompt_text, raw_response, parsed_response (jsonb), status, error_message, created_at
   - Status: pending, processing, completed, failed, skipped
   - Belongs to ContentItem

2. **Add fields to ContentItem**
   - summary (text, max 280 chars)
   - why_it_matters (text, max 500 chars)
   - ai_suggested_tags (array)
   - editorialised_at (timestamp)

3. **Create EditorialisationService**
   - Check eligibility (text length, not already processed)
   - Build prompt with guidelines
   - Call AI API (OpenAI/Anthropic)
   - Parse response
   - Store results

4. **Define prompt template**
   - Clear instructions
   - Length limits
   - Tone guidelines
   - "Never fabricate" instruction
   - Source attribution requirement

5. **Create EditorialisationJob**
   - Background processing
   - Retry logic
   - Rate limiting for API calls
   - Error handling

6. **Add admin controls**
   - Toggle editorialisation per source
   - View editorialisation history
   - Re-run for specific items

7. **Write tests**
   - Eligibility checks
   - Skip scenarios
   - Prompt versioning
   - Output parsing
   - Error handling

8. **Write documentation**
   - `docs/editorialisation.md`
   - Policy and guidelines
   - Prompt template
   - How to update prompts

---

## Work Log

(To be filled during implementation)

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
