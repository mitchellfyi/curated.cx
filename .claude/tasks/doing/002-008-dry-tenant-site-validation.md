# Task: Extract Tenant/Site Consistency Validation

## Metadata

| Field | Value |
|-------|-------|
| ID | `002-008-dry-tenant-site-validation` |
| Status | `todo` |
| Priority | `002` High |
| Created | `2026-01-23 01:00` |
| Started | |
| Completed | |
| Blocked By | |
| Blocks | |
| Assigned To | `worker-1` |
| Assigned At | `2026-01-23 10:09` |

---

## Context

Multiple models have identical validation logic for tenant/site consistency:

```ruby
# In Listing, Category, AND Source models:
validate :ensure_site_tenant_consistency

def ensure_site_tenant_consistency
  if site.present? && tenant.present? && site.tenant != tenant
    errors.add(:site, "must belong to the same tenant")
  end
end

before_validation :set_tenant_from_site

def set_tenant_from_site
  self.tenant ||= site&.tenant
end
```

This code is duplicated in at least 3 models. Since `set_tenant_from_site` runs before validation, the consistency check should never actually fail - making it partially redundant.

---

## Acceptance Criteria

- [ ] Create `app/models/concerns/tenant_site_consistency.rb`
- [ ] Extract `ensure_site_tenant_consistency` validation
- [ ] Extract `set_tenant_from_site` callback
- [ ] Include concern in Listing, Category, Source models
- [ ] Remove duplicate code from all models
- [ ] Consider if validation is even needed (since callback sets tenant)
- [ ] All existing tests pass
- [ ] Add spec for the concern
- [ ] Quality gates pass

---

## Plan

1. **Audit Current Usage**
   - Files: `app/models/listing.rb`, `app/models/category.rb`, `app/models/source.rb`
   - Confirm identical implementation
   - Check if any model has variations

2. **Create Concern**
   - File: `app/models/concerns/tenant_site_consistency.rb`
   ```ruby
   module TenantSiteConsistency
     extend ActiveSupport::Concern

     included do
       belongs_to :tenant
       belongs_to :site, optional: true

       before_validation :set_tenant_from_site
       validate :ensure_site_tenant_consistency
     end

     private

     def set_tenant_from_site
       self.tenant ||= site&.tenant
     end

     def ensure_site_tenant_consistency
       return unless site.present? && tenant.present?
       return if site.tenant_id == tenant_id

       errors.add(:site, "must belong to the same tenant")
     end
   end
   ```

3. **Update Models**
   - Include concern in each model
   - Remove duplicate methods

4. **Evaluate Necessity**
   - If callback always sets tenant correctly, is validation needed?
   - Consider: data imported via seeds, console, or API could bypass callback
   - Keep validation as safety net, but document why

5. **Test**
   - File: `spec/models/concerns/tenant_site_consistency_spec.rb`
   - Test auto-assignment of tenant from site
   - Test validation error when mismatched

---

## Work Log

(To be filled during execution)

---

## Notes

This is similar to task 001-002 (JsonbSettingsAccessor) - both are DRY extractions into concerns.

Consider combining with existing `TenantScoped` and `SiteScoped` concerns, or keeping separate for clarity.

---

## Links

- File: `app/models/listing.rb`
- File: `app/models/category.rb`
- File: `app/models/source.rb`
- File: `app/models/concerns/tenant_scoped.rb` (related)
