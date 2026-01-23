# Task: Refactor TenantResolver Middleware

## Metadata

| Field | Value |
|-------|-------|
| ID | `001-008-refactor-tenant-resolver` |
| Status | `todo` |
| Priority | `001` Critical |
| Created | `2026-01-23 01:00` |
| Started | |
| Completed | |
| Blocked By | |
| Blocks | |
| Assigned To | |
| Assigned At | |

---

## Context

The `TenantResolver` middleware is 178 lines and violates Single Responsibility:

1. **Domain Resolution** - Find site from hostname
2. **WWW/Apex Handling** - Redirect www ↔ non-www
3. **Subdomain Patterns** - Handle tenant subdomains
4. **Site Auto-Creation** - Create default sites for legacy tenants (side effect!)
5. **Error Handling** - Render 404 for unknown domains

**Major Issue: Implicit Site Creation**
```ruby
def create_default_site_for_tenant(tenant)
  site = Site.create!(...)  # Middleware creating records!
  site.domains.create!(...)
rescue ActiveRecord::RecordInvalid => e
  Site.find_by!(...)  # Race condition retry
end
```

Middleware should not create database records. This makes testing difficult and introduces race conditions.

---

## Acceptance Criteria

- [ ] Extract `DomainResolver` class for domain → site lookup
- [ ] Remove site auto-creation from middleware
- [ ] Move site creation to explicit admin action or rake task
- [ ] Reduce TenantResolver to ~50 lines (routing only)
- [ ] Add comprehensive specs for DomainResolver
- [ ] Handle race conditions properly (if creation needed elsewhere)
- [ ] All existing routes continue to work
- [ ] Quality gates pass

---

## Plan

1. **Extract DomainResolver**
   - File: `app/services/domain_resolver.rb`
   ```ruby
   class DomainResolver
     def initialize(hostname)
       @hostname = normalize(hostname)
     end

     def resolve
       find_by_exact_match ||
         find_by_www_variant ||
         find_by_subdomain_pattern
     end

     def site
       @site ||= resolve&.site
     end

     def tenant
       site&.tenant
     end
   end
   ```

2. **Simplify TenantResolver**
   - File: `app/middleware/tenant_resolver.rb`
   ```ruby
   def call(env)
     resolver = DomainResolver.new(env['HTTP_HOST'])

     if resolver.site
       set_current_context(resolver.site, resolver.tenant)
       @app.call(env)
     else
       render_not_found(env)
     end
   end
   ```

3. **Handle Site Creation Separately**
   - Create rake task: `rake tenants:ensure_default_sites`
   - Or: Admin UI action to create site
   - Or: Background job on tenant creation

4. **Test**
   - File: `spec/services/domain_resolver_spec.rb`
   - Test exact match, www variants, subdomains
   - Test not found scenarios
   - Test caching behavior

---

## Work Log

(To be filled during execution)

---

## Notes

Middleware design principles:
- Should be fast and stateless
- Should not modify database (reads only)
- Should be easily testable in isolation
- Side effects belong in controllers or jobs

Testing middleware:
```ruby
RSpec.describe TenantResolver do
  let(:app) { ->(env) { [200, {}, ['OK']] } }
  let(:middleware) { described_class.new(app) }

  it "sets Current.site for known domains" do
    env = { 'HTTP_HOST' => 'example.com' }
    middleware.call(env)
    expect(Current.site).to eq(expected_site)
  end
end
```

---

## Links

- File: `app/middleware/tenant_resolver.rb` (178 lines)
- File: `app/models/domain.rb` (hostname lookup)
- Pattern: https://guides.rubyonrails.org/rails_on_rack.html
