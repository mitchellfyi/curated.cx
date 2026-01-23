# Task: Extract DnsVerifier Service from Fat Domain Model

## Metadata

| Field | Value |
|-------|-------|
| ID | `001-005-extract-domain-dns-verifier` |
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

The `Domain` model is 277 lines and violates Single Responsibility Principle. It handles:
- Domain attributes and validations (appropriate)
- DNS verification logic (80+ lines - should be extracted)
- Status helpers and presentation logic (could be decorator)
- Hostname normalization utilities

DNS verification methods that should be extracted:
```ruby
def verify_dns_resolution
def check_dns!
def dns_verified?
def expected_dns_target
def current_dns_records
# ... and more
```

**SOLID Principle**: Single Responsibility - a class should have only one reason to change.

---

## Acceptance Criteria

- [ ] Create `app/services/dns_verifier.rb` service class
- [ ] Move all DNS verification logic to service
- [ ] Domain model delegates to service for DNS operations
- [ ] Service is independently testable
- [ ] Domain model reduced by ~80 lines
- [ ] All existing functionality preserved
- [ ] Add comprehensive specs for DnsVerifier
- [ ] Quality gates pass

---

## Plan

1. **Identify Methods to Extract**
   - File: `app/models/domain.rb`
   - List all DNS-related methods
   - Identify dependencies (what domain attributes they need)

2. **Create DnsVerifier Service**
   - File: `app/services/dns_verifier.rb`
   ```ruby
   class DnsVerifier
     def initialize(domain)
       @domain = domain
       @hostname = domain.hostname
       @expected_target = ENV['DNS_TARGET']
     end

     def verify!
     def verified?
     def current_records
     def check_resolution
   end
   ```

3. **Update Domain Model**
   ```ruby
   def dns_verifier
     @dns_verifier ||= DnsVerifier.new(self)
   end

   delegate :verify!, :verified?, to: :dns_verifier, prefix: :dns
   ```

4. **Consider DomainStatus Value Object**
   - Extract status-related methods if time permits
   - `next_step`, `status_color`, `status_badge`

5. **Test**
   - File: `spec/services/dns_verifier_spec.rb`
   - Test verification logic in isolation
   - Mock DNS lookups

---

## Work Log

(To be filled during execution)

---

## Notes

Service object patterns in Rails:
- Initialize with the model/resource
- Methods are verbs (actions): `verify!`, `check`, `resolve`
- Return meaningful results, not just true/false
- Raise specific exceptions for failures

Consider:
- Making DNS lookups async (background job)
- Caching DNS results with TTL
- Rate limiting DNS checks

---

## Links

- File: `app/models/domain.rb` (277 lines)
- Pattern: https://www.toptal.com/ruby-on-rails/rails-service-objects-tutorial
