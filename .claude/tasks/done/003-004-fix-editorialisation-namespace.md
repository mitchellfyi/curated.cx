# Task: Fix Editorialisation Namespace Conflict

## Metadata

| Field | Value |
|-------|-------|
| ID | `003-004-fix-editorialisation-namespace` |
| Status | `done` |
| Priority | `003` Medium |
| Created | `2026-01-23 12:05` |
| Started | `2026-01-24` |
| Completed | `2026-01-24` |
| Blocked By | |
| Blocks | |
| Assigned To | |
| Assigned At | |

---

## Context

There is a namespace conflict between `app/models/editorialisation.rb` (a model class) and `app/services/editorialisation/` (a module/namespace for services).

When Zeitwerk autoloads, it encounters:
```
TypeError: Editorialisation is not a module
/app/models/editorialisation.rb:8: previous definition of Editorialisation was here
```

This prevents specs from loading:
- `spec/services/editorialisation/ai_client_spec.rb`
- `spec/services/editorialisation/prompt_manager_spec.rb`

This blocks `./bin/quality` from completing the test suite.

---

## Acceptance Criteria

- [x] Namespace conflict resolved - both model and services can coexist (N/A - no conflict exists)
- [x] `Editorialisation` model functions correctly
- [x] `EditorialisationService` service functions correctly (not Editorialisation::AiClient)
- [x] All related specs pass (57 examples, 0 failures)
- [x] `./bin/quality` passes all checks
- [x] Quality gates pass

---

## Plan

1. **Analyze the conflict**
   - Files: `app/models/editorialisation.rb`, `app/services/editorialisation/`
   - Actions: Understand current structure and usage

2. **Choose resolution strategy** (options):
   - Option A: Rename model to `EditorialisationRecord` or similar
   - Option B: Move services under a different namespace (e.g., `Editorialisation::Services::`)
   - Option C: Convert model to be inside the module namespace
   - Option D: Use inflections to separate the two

3. **Implement chosen approach**
   - Update all references throughout codebase
   - Update associations, factories, specs

4. **Test thoroughly**
   - Run full test suite
   - Run quality checks

---

## Work Log

### 2026-01-23 12:05 - Task Created

Created as follow-up from 003-001-add-comments-views review phase.
This is a blocker for the full quality gate suite.

### 2026-01-24 - Task Obsolete

Investigated and found no namespace conflict exists:
- `app/models/editorialisation.rb` - Editorialisation class
- `app/services/editorialisation_service.rb` - EditorialisationService class

There is no `app/services/editorialisation/` directory that would conflict. The task was created based on an outdated state or misunderstanding.

All 57 related specs pass.

---

## Testing Evidence

```
bundle exec rspec spec/models/editorialisation_spec.rb spec/services/editorialisation_service_spec.rb

57 examples, 0 failures
```

---

## Notes

- This is a critical fix as it blocks the full quality gate suite
- Consider Rails/Zeitwerk naming conventions when choosing the fix

---

## Links

- Related: `003-001-add-comments-views` - Discovered during quality check
- File: `app/models/editorialisation.rb`
- File: `app/services/editorialisation/ai_client.rb`
- File: `app/services/editorialisation/prompt_manager.rb`
