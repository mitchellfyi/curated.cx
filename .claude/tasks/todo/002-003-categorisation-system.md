# Task: Add Rule-Based Categorisation System

## Metadata

| Field | Value |
|-------|-------|
| ID | `002-003-categorisation-system` |
| Status | `todo` |
| Priority | `002` High |
| Created | `2025-01-23 00:05` |
| Started | |
| Completed | |
| Blocked By | `002-001-ingestion-storage-model` |
| Blocks | `002-004-ai-editorialisation` |

---

## Context

ContentItems need automatic categorisation without relying on AI (for speed, cost, and explainability). This first-pass system uses rules based on URL patterns, source metadata, and keywords.

Each ContentItem gets:
- Topic tags (from site-defined taxonomy)
- Content type (news, article, job, tool, service, person)
- Confidence score

The system must be explainable - users should understand why content was tagged a certain way.

---

## Acceptance Criteria

- [ ] Taxonomy model exists (site-scoped, hierarchical tags)
- [ ] TaggingRule model exists for defining rules
- [ ] ContentItem gets topic_tags, content_type, confidence_score fields
- [ ] Rule types supported:
  - [ ] URL pattern matching (regex)
  - [ ] Source-based (tag by source)
  - [ ] Keyword matching (in title/text)
  - [ ] Domain matching
- [ ] Rules are evaluated in priority order
- [ ] Confidence score reflects match strength
- [ ] Tagging runs after ingestion (inline or background)
- [ ] Admin UI for managing taxonomy
- [ ] Admin UI for managing tagging rules
- [ ] Tests cover all rule types
- [ ] Tests verify confidence scoring
- [ ] `docs/tagging.md` explains system and extensibility
- [ ] Quality gates pass
- [ ] Changes committed with task reference

---

## Plan

1. **Create Taxonomy model**
   - Fields: site_id, name, slug, parent_id (for hierarchy), description
   - Nested set or ancestry gem for tree structure
   - Scoped to Site

2. **Create TaggingRule model**
   - Fields: site_id, taxonomy_id, rule_type, pattern, priority, enabled
   - Rule types: url_pattern, source, keyword, domain
   - Scoped to Site

3. **Create TaggingService**
   - Evaluate rules against ContentItem
   - Apply matching tags
   - Calculate confidence score
   - Log reasoning for explainability

4. **Add fields to ContentItem**
   - topic_tags (array of taxonomy slugs)
   - content_type (enum)
   - tagging_confidence (decimal)
   - tagging_explanation (text, optional)

5. **Integrate with ingestion**
   - Call TaggingService after ContentItem creation
   - Can be inline or queued

6. **Build admin UI**
   - Taxonomy tree management
   - Rule CRUD with pattern testing
   - Preview/test rules against sample content

7. **Write tests**
   - Each rule type
   - Priority ordering
   - Confidence calculation
   - Multi-tag scenarios

8. **Write documentation**
   - `docs/tagging.md`
   - How rules work
   - How to extend with new rule types

---

## Work Log

(To be filled during implementation)

---

## Testing Evidence

(To be filled during implementation)

---

## Notes

- Start simple - URL and keyword rules cover most cases
- Consider adding "anti-rules" that exclude content
- Confidence score: 1.0 = exact match, lower for fuzzy/keyword
- May want to expose tagging explanation in admin for debugging

---

## Links

- Dependency: `002-001-ingestion-storage-model`
- Mission: `MISSION.md` - "Normalise: classify, tag"
