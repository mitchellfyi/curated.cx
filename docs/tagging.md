# Rule-Based Content Tagging System

## Overview

The tagging system automatically categorises content items using rule-based matching without relying on AI. This provides:

- **Speed**: Instant categorisation on content ingestion
- **Cost**: No API calls required for basic categorisation
- **Explainability**: Users can understand exactly why content was tagged
- **Flexibility**: Site administrators can define custom taxonomy and rules

## Architecture

### Models

```
Taxonomy (site-scoped, hierarchical)
├── name: String
├── slug: String (unique per site)
├── description: Text
├── parent_id: Reference to parent Taxonomy
└── position: Integer (ordering)

TaggingRule (site-scoped)
├── taxonomy_id: Reference to Taxonomy (tag to apply)
├── rule_type: Enum (url_pattern, source, keyword, domain)
├── pattern: Text (rule-specific pattern to match)
├── priority: Integer (lower = evaluated first)
└── enabled: Boolean

ContentItem (modified)
├── topic_tags: JSONB Array (taxonomy slugs)
├── content_type: String (news, article, job, tool, etc.)
├── tagging_confidence: Decimal (0.0 - 1.0)
└── tagging_explanation: JSONB Array (rule match details)
```

### Service

`TaggingService` orchestrates rule evaluation:

```ruby
# Usage
result = TaggingService.tag(content_item)
# => {
#      topic_tags: ["tech", "news"],
#      content_type: nil,
#      confidence: 0.9,
#      explanation: [
#        { rule_id: 1, taxonomy_slug: "tech", reason: "URL matched pattern '.*github\\.com.*'" },
#        { rule_id: 5, taxonomy_slug: "news", reason: "Keywords matched: announcement, release" }
#      ]
#    }
```

### Integration

Tagging runs automatically via an `after_create` callback on `ContentItem`:

```ruby
class ContentItem < ApplicationRecord
  after_create :apply_tagging_rules

  private

  def apply_tagging_rules
    result = TaggingService.tag(self)
    return if result[:topic_tags].empty?

    update_columns(
      topic_tags: result[:topic_tags],
      tagging_confidence: result[:confidence],
      tagging_explanation: result[:explanation]
    )
  end
end
```

## Rule Types

### 1. URL Pattern (`url_pattern`)

Matches against `content_item.url_canonical` using Ruby regex.

| Confidence | Value |
|------------|-------|
| On match | **1.0** |

**Pattern format**: Ruby regular expression (case-insensitive)

**Examples**:
- `.*github\.com.*` - Match any GitHub URL
- `.*\/blog\/.*` - Match URLs containing /blog/
- `.*\.(pdf|doc|docx)$` - Match document file extensions

**Use cases**: Precise categorisation based on URL structure

### 2. Source-Based (`source`)

Matches content items from a specific ingestion source.

| Confidence | Value |
|------------|-------|
| On match | **0.9** |

**Pattern format**: Source ID (integer as string)

**Examples**:
- `42` - Match all content from Source with ID 42
- `17` - Match all content from Source with ID 17

**Use cases**: Tag all content from a known feed (e.g., all items from "TechCrunch RSS" get tagged "tech-news")

### 3. Keyword Matching (`keyword`)

Searches for keywords in title, description, and extracted text.

| Confidence | Range |
|------------|-------|
| 1 keyword match | **0.8** |
| 2 keyword matches | **0.9** (max) |
| Formula | `min(0.7 + 0.1 × match_count, 0.9)` |

**Pattern format**: Comma-separated keywords (case-insensitive)

**Examples**:
- `kubernetes,docker,container` - Match container-related content
- `startup,funding,investment,vc` - Match startup funding news
- `tutorial,guide,how-to` - Match educational content

**Use cases**: Topic-based categorisation using semantic keywords

### 4. Domain Matching (`domain`)

Matches against the domain/host portion of the URL.

| Confidence | Value |
|------------|-------|
| On match | **0.85** |

**Pattern format**: Domain pattern with optional wildcards (`*`)

**Examples**:
- `github.com` - Match exact domain
- `*.medium.com` - Match Medium custom domains
- `news.*` - Match any news.* domain
- `*.gov` - Match government sites

**Use cases**: Domain-based trust signals or source categorisation

## Priority Ordering

Rules are evaluated in **ascending priority order** (lower number = higher priority).

```
Priority 10: url_pattern for /security/  → Tagged: security (if matches)
Priority 20: source rule for TechCrunch  → Tagged: tech-news (if matches)
Priority 30: keyword rule for "security" → Tagged: security (if not already tagged)
```

All matching rules contribute tags. Confidence is taken from the highest-confidence match.

**Recommended priority ranges**:
- `1-50`: High-precision rules (URL patterns, specific sources)
- `51-100`: Medium-precision rules (domain matching)
- `101-200`: Fallback rules (keyword matching)

## Confidence Scoring

| Rule Type | Confidence | Rationale |
|-----------|------------|-----------|
| `url_pattern` | 1.0 | Explicit URL structure is definitive |
| `source` | 0.9 | Source provenance is reliable |
| `domain` | 0.85 | Domain indicates likely content type |
| `keyword` | 0.7-0.9 | Varies with match count; less precise |

The final `tagging_confidence` on a ContentItem is the **maximum** confidence from all matched rules.

## Explanation Format

Each rule match is recorded in `tagging_explanation`:

```json
[
  {
    "rule_id": 1,
    "taxonomy_slug": "tech",
    "reason": "URL matched pattern '.*github\\.com.*'"
  },
  {
    "rule_id": 5,
    "taxonomy_slug": "news",
    "reason": "Keywords matched: announcement, release"
  }
]
```

This enables:
- Debugging why content was tagged
- User-facing explanations
- Rule effectiveness analysis

## Admin UI

### Managing Taxonomy

Navigate to **Admin → Taxonomies** to:

- Create hierarchical topic tags
- Set display order (position)
- View child tags
- Edit/delete existing tags

### Managing Tagging Rules

Navigate to **Admin → Tagging Rules** to:

- Create rules linked to taxonomy tags
- Set rule type, pattern, and priority
- Enable/disable rules
- Test rules against existing content (Test action)

## Extensibility

### Adding a New Rule Type

1. **Add enum value** in `TaggingRule`:
```ruby
enum :rule_type, { url_pattern: 0, source: 1, keyword: 2, domain: 3, new_type: 4 }
```

2. **Implement matcher** in `TaggingRule#matches?`:
```ruby
def matches?(content_item)
  case rule_type
  # ... existing cases
  when "new_type"
    evaluate_new_type(content_item)
  end
end

private

def evaluate_new_type(content_item)
  # Your matching logic
  # Return: { match: bool, confidence: float, reason: string }
end
```

3. **Add translations** in `config/locales/en.yml`:
```yaml
en:
  activerecord:
    enums:
      tagging_rule:
        rule_type:
          new_type: "New Type"
```

4. **Add admin UI options** in views (form selects)

5. **Write tests** for the new rule type

### Adding Content Type Detection

Currently `content_type` is not set by rules. To implement:

```ruby
# In TaggingService#build_result
def build_result(matched_rules)
  # ... existing code

  # Determine content_type from rules or heuristics
  content_type = determine_content_type(matched_rules, @content_item)

  {
    topic_tags: topic_tags,
    content_type: content_type,  # Now populated
    confidence: max_confidence,
    explanation: explanation
  }
end

def determine_content_type(matched_rules, content_item)
  # Example: use URL patterns or dedicated content_type rules
  return "job" if content_item.url_canonical&.include?("/jobs/")
  return "tool" if matched_rules.any? { |m| m[:taxonomy].slug == "tools" }
  nil
end
```

## Troubleshooting

### Content Not Being Tagged

1. **Check rules are enabled**: Rules with `enabled: false` are skipped
2. **Check site scope**: Rules only apply to content from the same site
3. **Check pattern syntax**: Invalid regex patterns return no match
4. **Check priority order**: Lower priority rules run first

### Unexpected Tags

1. **Review explanation**: Check `content_item.tagging_explanation` for matched rules
2. **Verify pattern**: Broad patterns may match unintended content
3. **Check priority**: Higher-priority rules may be applying first

### Performance

The tagging service makes a single database query for rules (with eager loading) and evaluates them in Ruby. For sites with many rules (>100), consider:

- Index optimization on `tagging_rules` table
- Caching rule sets per site
- Async tagging via background job

## Database Schema

### taxonomies

```sql
CREATE TABLE taxonomies (
  id bigserial PRIMARY KEY,
  site_id bigint NOT NULL REFERENCES sites(id),
  tenant_id bigint NOT NULL REFERENCES tenants(id),
  name varchar NOT NULL,
  slug varchar NOT NULL,
  description text,
  parent_id bigint REFERENCES taxonomies(id),
  position integer DEFAULT 0 NOT NULL,
  created_at timestamp NOT NULL,
  updated_at timestamp NOT NULL
);

CREATE UNIQUE INDEX index_taxonomies_on_site_id_and_slug ON taxonomies(site_id, slug);
CREATE INDEX index_taxonomies_on_site_id_and_parent_id ON taxonomies(site_id, parent_id);
```

### tagging_rules

```sql
CREATE TABLE tagging_rules (
  id bigserial PRIMARY KEY,
  site_id bigint NOT NULL REFERENCES sites(id),
  tenant_id bigint NOT NULL REFERENCES tenants(id),
  taxonomy_id bigint NOT NULL REFERENCES taxonomies(id),
  rule_type integer NOT NULL,
  pattern text NOT NULL,
  priority integer DEFAULT 100 NOT NULL,
  enabled boolean DEFAULT true NOT NULL,
  created_at timestamp NOT NULL,
  updated_at timestamp NOT NULL
);

CREATE INDEX index_tagging_rules_on_site_id_and_priority ON tagging_rules(site_id, priority);
CREATE INDEX index_tagging_rules_on_site_id_and_enabled ON tagging_rules(site_id, enabled);
```

### content_items (added columns)

```sql
ALTER TABLE content_items
  ADD COLUMN topic_tags jsonb DEFAULT '[]' NOT NULL,
  ADD COLUMN content_type varchar,
  ADD COLUMN tagging_confidence decimal(3,2),
  ADD COLUMN tagging_explanation jsonb DEFAULT '[]' NOT NULL;

CREATE INDEX index_content_items_on_site_id_and_content_type ON content_items(site_id, content_type);
```

## Related Documentation

- [QUALITY_ENFORCEMENT.md](QUALITY_ENFORCEMENT.md) - Quality gates and testing requirements
- [ERROR_HANDLING.md](ERROR_HANDLING.md) - Error handling patterns
- [ANTI_PATTERN_PREVENTION.md](ANTI_PATTERN_PREVENTION.md) - Anti-patterns to avoid
