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
| Assigned To | |
| Assigned At | |
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

### Implementation Plan (Updated 2026-01-23 PLANNING PHASE)

#### Gap Analysis

| Criterion | Status | Gap |
|-----------|--------|-----|
| Taxonomy model (site-scoped, hierarchical) | ✅ COMPLETE | app/models/taxonomy.rb exists with parent/children |
| TaggingRule model | ✅ COMPLETE | app/models/tagging_rule.rb exists with all rule types |
| ContentItem tagging fields | ⚠️ MIGRATION EXISTS | Migration exists but NOT RUN (fields not in schema.rb) |
| URL pattern matching rule | ✅ COMPLETE | Implemented in TaggingRule#matches? |
| Source-based rule | ✅ COMPLETE | Implemented in TaggingRule#matches? |
| Keyword matching rule | ✅ COMPLETE | Implemented in TaggingRule#matches? |
| Domain matching rule | ✅ COMPLETE | Implemented in TaggingRule#matches? |
| Priority-ordered evaluation | ✅ COMPLETE | TaggingService fetches by_priority |
| Confidence scoring | ✅ COMPLETE | url=1.0, source=0.9, domain=0.85, keyword=0.7-0.9 |
| Tagging after ingestion | ✅ COMPLETE | ContentItem#after_create :apply_tagging_rules |
| Admin UI for taxonomy | ✅ COMPLETE | Controller, views, routes in place |
| Admin UI for tagging rules | ✅ COMPLETE | Controller, views, routes, test action in place |
| Tests for all rule types | ✅ COMPLETE | 7 spec files with ~150 examples total |
| Tests for confidence scoring | ✅ COMPLETE | Covered in spec/services/tagging_service_spec.rb |
| docs/tagging.md | ❌ MISSING | Must be created |
| Quality gates pass | ⚠️ NEEDS VERIFICATION | ./bin/quality not yet run this session |
| Changes committed with task reference | ✅ COMPLETE | 12 commits from 61d49f1 to 83cea8c |

**Summary:**
- Implementation is 90%+ complete from previous sessions
- Migrations exist but are NOT applied to database
- Documentation is missing

---

#### Remaining Work (Priority Order)

**1. Run Database Migrations**
```bash
bundle exec rails db:migrate
```
- `20260123030621_create_taxonomies.rb`
- `20260123030622_create_tagging_rules.rb`
- `20260123030623_add_tagging_fields_to_content_items.rb`

**2. Create Documentation**
Create `doc/tagging.md` with:
- System overview (purpose, architecture)
- Rule types explained (url_pattern, source, keyword, domain)
- Confidence scoring algorithm (url=1.0, source=0.9, domain=0.85, keyword=0.7-0.9)
- How to add new rule types (extensibility guide)
- Admin UI usage guide
- Troubleshooting common issues

**3. Run Tests**
```bash
bundle exec rspec spec/models/taxonomy_spec.rb spec/models/tagging_rule_spec.rb \
  spec/services/tagging_service_spec.rb spec/services/admin/taxonomies_service_spec.rb \
  spec/services/admin/tagging_rules_service_spec.rb spec/requests/admin/taxonomies_spec.rb \
  spec/requests/admin/tagging_rules_spec.rb
```

**4. Run Quality Gates**
```bash
./bin/quality
```

**5. Update Model Annotations (if migrations applied)**
```bash
bundle exec annotaterb models
```

**6. Commit Any Remaining Changes**
Commit message format: `docs: Add tagging system documentation [002-003]`

---

#### Files Already Complete

| File | Status |
|------|--------|
| db/migrate/*_create_taxonomies.rb | ✅ |
| db/migrate/*_create_tagging_rules.rb | ✅ |
| db/migrate/*_add_tagging_fields_to_content_items.rb | ✅ |
| app/models/taxonomy.rb | ✅ |
| app/models/tagging_rule.rb | ✅ |
| app/models/content_item.rb | ✅ (callback added) |
| app/services/tagging_service.rb | ✅ |
| app/services/admin/taxonomies_service.rb | ✅ |
| app/services/admin/tagging_rules_service.rb | ✅ |
| app/controllers/admin/taxonomies_controller.rb | ✅ |
| app/controllers/admin/tagging_rules_controller.rb | ✅ |
| app/views/admin/taxonomies/* (6 files) | ✅ |
| app/views/admin/tagging_rules/* (6 files) | ✅ |
| config/routes.rb | ✅ |
| config/locales/en.yml | ✅ |
| config/locales/es.yml | ✅ |
| spec/factories/taxonomies.rb | ✅ |
| spec/factories/tagging_rules.rb | ✅ |
| spec/models/taxonomy_spec.rb | ✅ |
| spec/models/tagging_rule_spec.rb | ✅ |
| spec/services/tagging_service_spec.rb | ✅ |
| spec/services/admin/*_service_spec.rb | ✅ |
| spec/requests/admin/*_spec.rb | ✅ |

---

#### Files to Create

| File | Purpose |
|------|---------|
| doc/tagging.md | System documentation |

---

#### Test Plan Status

All tests written but NOT EXECUTED (database was not running in previous session):
- [x] spec/models/taxonomy_spec.rb - 28 examples
- [x] spec/models/tagging_rule_spec.rb - 35 examples
- [x] spec/services/tagging_service_spec.rb - 24 examples
- [x] spec/services/admin/taxonomies_service_spec.rb - 12 examples
- [x] spec/services/admin/tagging_rules_service_spec.rb - 13 examples
- [x] spec/requests/admin/taxonomies_spec.rb - 21 examples
- [x] spec/requests/admin/tagging_rules_spec.rb - 24 examples

---

## Work Log

### 2026-01-23 03:47 - Documentation Sync (Phase 5)

**Documentation Status:**
- `doc/tagging.md` - ✅ Already exists (374 lines, comprehensive)
  - System overview and architecture
  - Rule types explained (url_pattern, source, keyword, domain)
  - Confidence scoring algorithm
  - Admin UI usage guide
  - Extensibility guide
  - Troubleshooting section
  - Database schema reference

**Related Documentation Links Verified:**
- `doc/QUALITY_ENFORCEMENT.md` - ✅ Exists
- `doc/ERROR_HANDLING.md` - ✅ Exists
- `doc/ANTI_PATTERN_PREVENTION.md` - ✅ Exists

**Model Annotations:**
- `bundle exec annotaterb models` - ❌ BLOCKED (database unavailable)
- ContentItem model has existing annotations (lines 3-34) but missing new columns:
  - `topic_tags`, `content_type`, `tagging_confidence`, `tagging_explanation`
- Taxonomy and TaggingRule models have no annotations yet
- Will sync when database is available and migrations applied

**Consistency Checks:**
- [x] Code matches documentation
- [x] No broken links in markdown
- [ ] Schema annotations current (blocked by database)

**No Changes Needed:**
- All documentation already up-to-date from previous session
- No new code features to document

### 2026-01-23 03:42 - Testing Phase (Phase 4)

**Static Analysis - All Passed:**
- RuboCop: 243 files inspected, no offenses detected
- ERB Lint: 70 files linted, no errors found
- Brakeman: 0 security warnings
- Bundle Audit: No vulnerabilities found
- Strong Migrations: All migrations safe for production

**Spec File Validation - All Passed:**
- Ruby syntax validated for all 7 spec files
- Ruby syntax validated for all 5 model/service files

**Test Files Verified (7 spec files, ~157 examples):**
| File | Examples | Coverage |
|------|----------|----------|
| spec/models/taxonomy_spec.rb | ~28 | Associations, validations, callbacks, scopes, hierarchy, site isolation |
| spec/models/tagging_rule_spec.rb | ~35 | Associations, validations, enums, scopes, matches? for all 4 rule types |
| spec/services/tagging_service_spec.rb | ~24 | All rule types, priority ordering, confidence scoring, site isolation |
| spec/services/admin/taxonomies_service_spec.rb | ~12 | Tenant/site scoping, tree ordering, find methods |
| spec/services/admin/tagging_rules_service_spec.rb | ~13 | Tenant/site scoping, priority ordering, find methods |
| spec/requests/admin/taxonomies_spec.rb | ~21 | CRUD actions, tenant isolation, hierarchy features |
| spec/requests/admin/tagging_rules_spec.rb | ~24 | CRUD actions, tenant isolation, rule types, test action |

**Quality Gates Run:**
```
./bin/quality
```
Results:
- ✅ RuboCop Rails Omakase - Code Style Compliance
- ✅ ERB Lint - Template Quality
- ✅ Brakeman - Security Vulnerability Scan
- ✅ Bundle Audit - Gem Security Check
- ✅ Strong Migrations - Safe Migration Analysis
- ❌ RSpec Core Tests - BLOCKED (database connection unavailable)

**Blocker:**
- Database connection unavailable (Postgres.app permission dialog)
- Cannot run actual RSpec tests or migrations
- Tests are syntactically valid and follow project patterns

**Next Steps (when database available):**
1. Run migrations: `bundle exec rails db:migrate`
2. Run tests: `bundle exec rspec spec/models/taxonomy_spec.rb spec/models/tagging_rule_spec.rb spec/services/tagging_service_spec.rb spec/services/admin spec/requests/admin/taxonomies_spec.rb spec/requests/admin/tagging_rules_spec.rb`
3. Update model annotations: `bundle exec annotaterb models`

### 2026-01-23 03:40 - Implementation Progress

**Documentation Created:**
- Created `doc/tagging.md` (373 lines) with comprehensive documentation:
  - System overview and architecture
  - Rule types explained (url_pattern, source, keyword, domain)
  - Confidence scoring algorithm table
  - Priority ordering guide
  - Admin UI usage guide
  - Extensibility guide for adding new rule types
  - Troubleshooting section
  - Database schema reference

**Quality Gates Verified:**
- RuboCop: 7 files inspected, no offenses detected
- Brakeman: 0 security warnings
- ERB Lint: 12 files, no errors found

**Blockers:**
- Database connection unavailable (Postgres.app permission dialog issue)
- Cannot run migrations or tests until database is accessible
- Model annotations cannot be updated without database

**Commit:** `8bf95b9` - docs: Add tagging system documentation [002-003]

**Files Created:**
- doc/tagging.md (373 lines)

**Status:**
- All implementation code complete (from previous sessions)
- Documentation complete ✅
- Migrations exist but NOT APPLIED (blocked by database)
- Tests exist but NOT RUN (blocked by database)

### 2026-01-23 03:30 - Planning Phase Complete

**Gap Analysis Results:**
- Implementation is 90%+ complete from previous sessions (12 commits)
- All code files exist and are complete:
  - Models: Taxonomy, TaggingRule (with matches? method for all 4 rule types)
  - Services: TaggingService, Admin::TaxonomiesService, Admin::TaggingRulesService
  - Controllers: Admin::TaxonomiesController, Admin::TaggingRulesController
  - Views: 12 ERB files (6 for taxonomies, 6 for tagging_rules)
  - Factories: taxonomies.rb, tagging_rules.rb (with traits)
  - Tests: 7 spec files (~150 examples total)
  - Routes: Configured with test action for tagging_rules
  - Locales: en.yml and es.yml translations complete

**Gaps Identified:**
1. ❌ **Migrations NOT RUN** - schema.rb doesn't have taxonomies/tagging_rules tables or new content_items fields
2. ❌ **doc/tagging.md MISSING** - Documentation not created
3. ⚠️ **Tests NOT EXECUTED** - Database wasn't available in previous session
4. ⚠️ **Quality gates NOT VERIFIED** - ./bin/quality not run this session

**Remaining Work (in order):**
1. Run migrations: `bundle exec rails db:migrate`
2. Create doc/tagging.md documentation
3. Run tests for all new code
4. Run ./bin/quality and fix any issues
5. Update model annotations
6. Commit documentation changes

### 2026-01-23 03:29 - Triage Complete

- Dependencies: ✅ `002-001-ingestion-storage-model` is in done/ with status=done and all criteria checked
- Task clarity: Clear - well-defined acceptance criteria with detailed plan
- Ready to proceed: Yes
- Notes:
  - Task already has significant work completed (see previous work log entries)
  - Implementation committed in 12 commits (61d49f1 through 83cea8c)
  - Tests written but not executed (database not running in previous session)
  - Documentation (docs/tagging.md) still pending
  - Acceptance criteria checkboxes need to be verified and checked
  - Quality gates need final run and verification
  - Need to verify all implementation files exist and are correct

### 2026-01-23 03:24 - Testing Complete

**Tests written (7 spec files, ~1500 lines):**
- spec/models/taxonomy_spec.rb - 28 examples
- spec/models/tagging_rule_spec.rb - 35 examples
- spec/services/tagging_service_spec.rb - 24 examples
- spec/services/admin/taxonomies_service_spec.rb - 12 examples
- spec/services/admin/tagging_rules_service_spec.rb - 13 examples
- spec/requests/admin/taxonomies_spec.rb - 21 examples
- spec/requests/admin/tagging_rules_spec.rb - 24 examples

**Test coverage:**
- All rule types (url_pattern, source, keyword, domain)
- Confidence scoring for each rule type
- Priority ordering
- Multiple matching rules
- Tenant/site isolation
- Admin CRUD operations
- Edge cases (blank values, invalid regex, disabled rules)

**Quality gates:**
- RuboCop: 7 files inspected, no offenses detected
- Brakeman: 0 security warnings

**Commit:** `83cea8c` - test: Add specs for categorisation system [002-003]

**Note:** Database connection unavailable (Postgres.app permissions), so tests not executed. Specs written following project patterns.

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

### 2026-01-23 03:24 - Testing Complete

**Tests written:**
- spec/models/taxonomy_spec.rb - Associations, validations, callbacks, scopes, hierarchy methods, site isolation
- spec/models/tagging_rule_spec.rb - Associations, validations, enums, scopes, matches? method for all rule types
- spec/services/tagging_service_spec.rb - All rule types, priority ordering, confidence scoring, explanation building
- spec/services/admin/taxonomies_service_spec.rb - Tenant/site scoping, tree ordering, find methods
- spec/services/admin/tagging_rules_service_spec.rb - Tenant/site scoping, priority ordering, find methods
- spec/requests/admin/taxonomies_spec.rb - CRUD actions, tenant isolation, hierarchy features
- spec/requests/admin/tagging_rules_spec.rb - CRUD actions, tenant isolation, rule type features, test action

**Quality gates:**
- RuboCop: 7 files inspected, no offenses detected
- Brakeman: 0 security warnings

**Commit:** `83cea8c` - test: Add specs for categorisation system [002-003]

**Note:** Database is not running so tests could not be executed, but all specs have been written following the existing project patterns and RuboCop validation passes.

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
