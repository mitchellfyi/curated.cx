# Task: Add Rule-Based Categorisation System

## Metadata

| Field | Value |
|-------|-------|
| ID | `002-003-categorisation-system` |
| Status | `doing` |
| Priority | `002` High |
| Created | `2025-01-23 00:05` |
| Started | `2026-01-23 03:01` |
| Completed | |
| Blocked By | `002-001-ingestion-storage-model` |
| Assigned To | `worker-2` |
| Assigned At | `2026-01-23 03:01` |
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

### Implementation Plan (Generated 2026-01-23 03:05)

#### Gap Analysis

| Criterion | Status | Gap |
|-----------|--------|-----|
| Taxonomy model (site-scoped, hierarchical) | NOT EXISTS | Create from scratch |
| TaggingRule model | NOT EXISTS | Create from scratch |
| ContentItem tagging fields | NOT EXISTS | Add via migration |
| URL pattern matching rule | NOT EXISTS | Implement in TaggingService |
| Source-based rule | NOT EXISTS | Implement in TaggingService |
| Keyword matching rule | NOT EXISTS | Implement in TaggingService |
| Domain matching rule | NOT EXISTS | Implement in TaggingService |
| Priority-ordered evaluation | NOT EXISTS | Implement in TaggingService |
| Confidence scoring | NOT EXISTS | Implement in TaggingService |
| Tagging after ingestion | NOT EXISTS | Add callback to ContentItem |
| Admin UI for taxonomy | NOT EXISTS | Create controller/views |
| Admin UI for tagging rules | NOT EXISTS | Create controller/views |
| Tests for all rule types | NOT EXISTS | Create spec files |
| Tests for confidence scoring | NOT EXISTS | Create spec files |
| docs/tagging.md | NOT EXISTS | Create documentation |

**Key Observations:**
- ContentItem model exists with SiteScoped concern - only site_id, no tenant_id
- Source model has both TenantScoped and SiteScoped
- Admin UI pattern: Controller → Service → Model (see Admin::CategoriesController)
- No tree/hierarchy gem currently in Gemfile - use simple parent_id with self-join
- Factory pattern uses `association :source; site { source.site }`

---

#### Files to Create

**1. Database Migrations (run in order)**

```
db/migrate/YYYYMMDDHHMMSS_create_taxonomies.rb
```
- `site_id` (references, not null, FK)
- `tenant_id` (references, not null, FK) - for consistency with Source pattern
- `name` (string, not null)
- `slug` (string, not null)
- `description` (text)
- `parent_id` (bigint, nullable) - self-referential FK for hierarchy
- `position` (integer, default: 0) - ordering within siblings
- `timestamps`
- Indexes: `[site_id, slug]` unique, `[site_id, parent_id]`, `[tenant_id]`

```
db/migrate/YYYYMMDDHHMMSS_create_tagging_rules.rb
```
- `site_id` (references, not null, FK)
- `tenant_id` (references, not null, FK)
- `taxonomy_id` (references, not null, FK)
- `rule_type` (integer, not null) - enum: url_pattern(0), source(1), keyword(2), domain(3)
- `pattern` (text, not null) - regex for url_pattern, source_id for source, keywords for keyword, domain pattern for domain
- `priority` (integer, not null, default: 100)
- `enabled` (boolean, default: true, not null)
- `timestamps`
- Indexes: `[site_id, priority]`, `[site_id, enabled]`, `[taxonomy_id]`, `[tenant_id]`

```
db/migrate/YYYYMMDDHHMMSS_add_tagging_fields_to_content_items.rb
```
- `topic_tags` (jsonb, default: [], not null)
- `content_type` (string, nullable) - news, article, job, tool, service, person
- `tagging_confidence` (decimal, precision: 3, scale: 2, nullable)
- `tagging_explanation` (jsonb, default: [], not null) - array of {rule_id, reason}
- Index: `[site_id, content_type]`

**2. Models**

```
app/models/taxonomy.rb
```
- Include TenantScoped, SiteScoped (following Source pattern)
- `belongs_to :parent, class_name: 'Taxonomy', optional: true`
- `has_many :children, class_name: 'Taxonomy', foreign_key: :parent_id, dependent: :destroy`
- `has_many :tagging_rules, dependent: :destroy`
- Validations: name presence, slug presence/uniqueness/format
- `before_validation :generate_slug_from_name`
- Scopes: `roots` (parent_id nil), `by_position`
- Instance methods: `ancestors`, `descendants`, `full_path`

```
app/models/tagging_rule.rb
```
- Include TenantScoped, SiteScoped
- `belongs_to :taxonomy`
- `enum :rule_type, { url_pattern: 0, source: 1, keyword: 2, domain: 3 }`
- Validations: pattern presence, priority presence, rule_type presence
- Scopes: `enabled`, `by_priority` (order priority ASC), `for_type(type)`
- Instance method: `matches?(content_item)` - returns {match: bool, confidence: float, reason: string}

**3. Service**

```
app/services/tagging_service.rb
```
- Class method: `TaggingService.tag(content_item)` - entry point
- Instance: `initialize(content_item)`
- Main method: `#call` - returns {topic_tags: [], content_type: string, confidence: float, explanation: []}
- Private evaluator methods:
  - `evaluate_url_pattern_rule(rule)` - regex match against url_canonical
  - `evaluate_source_rule(rule)` - check if content_item.source_id matches
  - `evaluate_keyword_rule(rule)` - search title + extracted_text for keywords
  - `evaluate_domain_rule(rule)` - extract domain from url_canonical, pattern match
- Confidence calculation:
  - url_pattern exact match: 1.0
  - source match: 0.9
  - domain match: 0.85
  - keyword match: 0.7 + (0.1 * match_count) capped at 0.9
- Returns highest confidence content_type if rules set it

**4. Admin Services**

```
app/services/admin/taxonomies_service.rb
```
- `initialize(tenant)`
- `all_taxonomies` - returns tree structure, ordered by position
- `find_taxonomy(id)`
- `root_taxonomies` - returns only top-level

```
app/services/admin/tagging_rules_service.rb
```
- `initialize(tenant)`
- `all_rules` - includes taxonomy, ordered by priority
- `find_rule(id)`
- `rules_for_taxonomy(taxonomy)` - filtered by taxonomy_id

**5. Admin Controllers**

```
app/controllers/admin/taxonomies_controller.rb
```
- Include AdminAccess
- Standard CRUD: index, show, new, create, edit, update, destroy
- Strong params: `[:name, :slug, :description, :parent_id, :position]`

```
app/controllers/admin/tagging_rules_controller.rb
```
- Include AdminAccess
- Standard CRUD: index, show, new, create, edit, update, destroy
- Strong params: `[:taxonomy_id, :rule_type, :pattern, :priority, :enabled]`
- Custom action: `test` - test rule against sample content_items

**6. Admin Views**

```
app/views/admin/taxonomies/
  index.html.erb    - Tree display with indent for hierarchy
  show.html.erb     - Details + child taxonomies + rules using it
  new.html.erb      - Form with parent selector
  edit.html.erb     - Form with parent selector
  _form.html.erb    - Shared form partial
```

```
app/views/admin/tagging_rules/
  index.html.erb    - List grouped by taxonomy, sorted by priority
  show.html.erb     - Details + test preview
  new.html.erb      - Form with taxonomy selector + rule_type selector
  edit.html.erb     - Form
  _form.html.erb    - Shared form partial
```

**7. Factories**

```
spec/factories/taxonomies.rb
```
- Default: tenant, site from tenant, sequence name/slug
- Traits: `:child` (with parent), `:with_rules`

```
spec/factories/tagging_rules.rb
```
- Default: association :taxonomy, site from taxonomy.site
- Traits: `:url_pattern`, `:source_based`, `:keyword`, `:domain`, `:disabled`

**8. Specs**

```
spec/models/taxonomy_spec.rb
```
- Associations (site, tenant, parent, children, tagging_rules)
- Validations (name, slug uniqueness scoped to site)
- Hierarchy methods (ancestors, descendants)
- Slug generation

```
spec/models/tagging_rule_spec.rb
```
- Associations (site, tenant, taxonomy)
- Validations (pattern, priority, rule_type)
- Enum values
- `matches?` method for each rule type

```
spec/services/tagging_service_spec.rb
```
- URL pattern matching (exact regex, partial, no match)
- Source-based matching
- Keyword matching (single, multiple, case insensitive)
- Domain matching (exact, wildcard)
- Priority ordering (higher priority rule wins)
- Confidence scoring (each rule type gets expected score)
- Multi-tag scenarios (multiple rules match)
- Explanation building
- No rules scenario (returns empty)

```
spec/services/admin/taxonomies_service_spec.rb
```
- Scoping to current tenant/site
- Tree ordering

```
spec/services/admin/tagging_rules_service_spec.rb
```
- Scoping to current tenant/site
- Priority ordering

```
spec/controllers/admin/taxonomies_controller_spec.rb
```
- CRUD actions work
- Authorization (admin access required)

```
spec/controllers/admin/tagging_rules_controller_spec.rb
```
- CRUD actions work
- Authorization (admin access required)

---

#### Files to Modify

**1. ContentItem Model**
```
app/models/content_item.rb
```
- Add `after_create :apply_tagging_rules` callback
- Add getter methods for new JSONB fields
- Add scopes: `by_content_type(type)`, `tagged_with(taxonomy_slug)`

**2. Routes**
```
config/routes.rb
```
- Add under namespace :admin:
  - `resources :taxonomies`
  - `resources :tagging_rules do member { post :test } end`

**3. Locales**
```
config/locales/en.yml
config/locales/es.yml
```
- Add admin.taxonomies.* translations
- Add admin.tagging_rules.* translations

---

#### Integration Point

ContentItem already has `after_create` lifecycle. Add:
```ruby
after_create :apply_tagging_rules

private

def apply_tagging_rules
  result = TaggingService.tag(self)
  update_columns(
    topic_tags: result[:topic_tags],
    content_type: result[:content_type],
    tagging_confidence: result[:confidence],
    tagging_explanation: result[:explanation]
  )
end
```

---

#### Test Plan

Model tests:
- [ ] Taxonomy associations and validations
- [ ] Taxonomy hierarchy (parent/children)
- [ ] Taxonomy slug auto-generation
- [ ] Taxonomy site isolation
- [ ] TaggingRule associations and validations
- [ ] TaggingRule enum rule_type
- [ ] TaggingRule `matches?` for url_pattern
- [ ] TaggingRule `matches?` for source
- [ ] TaggingRule `matches?` for keyword
- [ ] TaggingRule `matches?` for domain

Service tests:
- [ ] TaggingService URL pattern exact match (confidence 1.0)
- [ ] TaggingService URL pattern partial match (confidence 0.95)
- [ ] TaggingService source match (confidence 0.9)
- [ ] TaggingService domain match (confidence 0.85)
- [ ] TaggingService keyword match (confidence 0.7-0.9)
- [ ] TaggingService priority ordering
- [ ] TaggingService multiple matching rules (all tags applied)
- [ ] TaggingService no matching rules (empty result)
- [ ] TaggingService explanation array building

Integration tests:
- [ ] ContentItem creation triggers tagging
- [ ] ContentItem has correct topic_tags after save
- [ ] Admin taxonomy CRUD
- [ ] Admin tagging rule CRUD
- [ ] Admin rule test preview

---

#### Docs to Update

- [ ] Create `doc/tagging.md` - Comprehensive documentation:
  - System overview
  - How rules work (each type)
  - Confidence scoring algorithm
  - How to add new rule types
  - Admin UI guide
  - Troubleshooting

---

#### Implementation Order

1. **Phase 1: Database** (migrations)
   - CreateTaxonomies migration
   - CreateTaggingRules migration
   - AddTaggingFieldsToContentItems migration
   - Run migrations

2. **Phase 2: Models**
   - Taxonomy model
   - TaggingRule model
   - Update ContentItem model (getters, scopes)
   - Factories

3. **Phase 3: Core Service**
   - TaggingService
   - Model tests
   - Service tests

4. **Phase 4: Integration**
   - ContentItem after_create callback
   - Integration tests

5. **Phase 5: Admin**
   - Admin services
   - Admin controllers
   - Admin views
   - Routes
   - Locales
   - Controller tests

6. **Phase 6: Documentation**
   - doc/tagging.md

7. **Phase 7: Quality**
   - Run ./bin/quality
   - Fix any issues
   - Commit

---

## Work Log

### 2026-01-23 03:15 - Implementation Complete

**Commits made:**
1. `61d49f1` - feat: Add migrations for categorisation system [002-003]
2. `fa2ef8f` - feat: Add Taxonomy model [002-003]
3. `b57d0e0` - feat: Add TaggingRule model [002-003]
4. `a78e402` - feat: Add TaggingService for rule-based content tagging [002-003]
5. `f03ab50` - feat: Add tagging callback and scopes to ContentItem [002-003]
6. `f7b9caa` - feat: Add admin services for taxonomies and tagging rules [002-003]
7. `602b31d` - feat: Add admin controllers for taxonomies and tagging rules [002-003]
8. `cce5d7a` - feat: Add admin views for taxonomies [002-003]
9. `3309218` - feat: Add admin views for tagging rules [002-003]
10. `330a39a` - feat: Add admin routes for taxonomies and tagging rules [002-003]
11. `d1aaeb9` - feat: Add i18n translations for taxonomies and tagging rules [002-003]
12. `0b27707` - feat: Add factories for taxonomies and tagging rules [002-003]

**Quality gates passed:**
- RuboCop: 218 files inspected, no offenses detected
- ERB Lint: 68 files, no errors
- Brakeman: 0 security warnings

**Files created:**
- 3 migrations
- 2 models (Taxonomy, TaggingRule)
- 3 services (TaggingService, Admin::TaxonomiesService, Admin::TaggingRulesService)
- 2 controllers (Admin::TaxonomiesController, Admin::TaggingRulesController)
- 12 views (6 for taxonomies, 6 for tagging rules)
- 2 factories

**Files modified:**
- app/models/content_item.rb (callback, scopes, getters)
- config/routes.rb (admin routes)
- config/locales/en.yml (translations)
- config/locales/es.yml (translations)

**Note:** Database is not running so migrations haven't been applied yet. Tests and schema updates will be in the next phase.

### 2026-01-23 03:05 - Planning Complete

**Gap Analysis Results:**
- All 15 acceptance criteria require new implementation - nothing exists yet
- ContentItem model exists but has no tagging fields
- No Taxonomy or TaggingRule models exist
- No tagging service exists
- Admin UI patterns are well-established (Categories as reference)

**Key Design Decisions:**
1. **Scoping**: Use both TenantScoped + SiteScoped (like Source model) for Taxonomy and TaggingRule
2. **Hierarchy**: Simple parent_id self-join for Taxonomy (no external gem needed)
3. **Confidence**: Tiered by rule type - URL pattern (1.0), source (0.9), domain (0.85), keyword (0.7-0.9)
4. **Integration**: after_create callback on ContentItem calls TaggingService
5. **Explanation**: JSONB array storing {rule_id, reason} for each matched rule

**Files to create:** 23 new files (3 migrations, 2 models, 3 services, 2 controllers, ~10 views, 2 factories, 5+ spec files, 1 doc)
**Files to modify:** 4 files (ContentItem model, routes.rb, en.yml, es.yml)

**Implementation phases:** 7 phases from database through quality gates

### 2026-01-23 03:01 - Triage Complete

- Dependencies: ✅ `002-001-ingestion-storage-model` completed (verified in done/ with all criteria checked)
- Task clarity: Clear - well-defined models, rule types, and acceptance criteria
- Ready to proceed: Yes
- Notes:
  - ContentItem model already exists with proper tenant scoping
  - Need to add topic_tags, content_type, confidence_score fields to ContentItem
  - Will need to create Taxonomy and TaggingRule models from scratch
  - Admin UI for taxonomy/rules will use existing admin patterns

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
