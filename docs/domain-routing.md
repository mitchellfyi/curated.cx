# Domain Routing - Hostname Resolution Rules

## Overview

Curated.cx resolves sites from the HTTP `Host` header using a multi-strategy approach. The `TenantResolver` middleware normalizes the hostname and attempts multiple resolution strategies to find the appropriate site.

---

## Hostname Normalization

All hostnames are normalized before resolution:

1. **Remove port**: `example.com:3000` → `example.com`
2. **Lowercase**: `EXAMPLE.COM` → `example.com`
3. **Strip trailing dots**: `example.com.` → `example.com`

**Example**:
```ruby
Domain.normalize_hostname("Example.COM:3000.")  # => "example.com"
```

---

## Resolution Strategies

The resolver tries strategies in order until a site is found:

### Strategy 1: Direct Hostname Lookup

Exact match against stored domain hostnames.

**Examples**:
- `ainews.cx` → finds domain with hostname `ainews.cx`
- `www.ainews.cx` → finds domain with hostname `www.ainews.cx`

### Strategy 2: www Variant (Apex → www)

If the request is for `www.example.com` and no exact match is found, try the apex domain `example.com`.

**Example**:
```
Request: www.ainews.cx
  → Try: www.ainews.cx (not found)
  → Try: ainews.cx (found!) → return site
```

### Strategy 3: www Variant (www → Apex)

If the request is for `example.com` and no exact match is found, try `www.example.com`.

**Example**:
```
Request: example.com
  → Try: example.com (not found)
  → Try: www.example.com (found!) → return site
```

### Strategy 4: Subdomain Pattern (Optional)

If the hostname looks like a subdomain pattern (e.g., `ai.curated.cx`):

1. Extract apex domain: `ai.curated.cx` → `curated.cx`
2. Find site for apex domain
3. Check if site has subdomain pattern enabled: `site.setting("domains.subdomain_pattern_enabled", false)`
4. If enabled, return the site

**Configuration**:
```ruby
# Enable subdomain pattern for a site
site.update_setting("domains.subdomain_pattern_enabled", true)
```

**Example**:
```
Request: ai.curated.cx
  → Extract apex: curated.cx
  → Find site for curated.cx
  → Check subdomain_pattern_enabled setting
  → If true: return site
  → If false: continue to next strategy
```

### Strategy 5: Tenant Fallback (Backward Compatibility)

For existing tenants that haven't been migrated to Site/Domain structure yet, fallback to direct tenant lookup.

**Example**:
```
Request: old-tenant.example.com
  → Try Domain lookup (not found)
  → Try Tenant.find_by_hostname! (found) → create default site → return site
```

---

## Resolution Examples

### Apex Domain
```
Request: ainews.cx
Strategy 1: Direct lookup → ✅ Found
Result: Site for ainews.cx
```

### www Variant
```
Request: www.ainews.cx
Strategy 1: Direct lookup → ❌ Not found
Strategy 2: Try ainews.cx → ✅ Found
Result: Site for ainews.cx (via www variant)
```

### Normalization
```
Request: AiNeWs.Cx:3000
Normalized: ainews.cx
Strategy 1: Direct lookup → ✅ Found
Result: Site for ainews.cx
```

### Subdomain Pattern
```
Request: ai.curated.cx
Strategy 1: Direct lookup → ❌ Not found
Strategy 2: Try www.ai.curated.cx → ❌ Not found
Strategy 3: Try ai.curated.cx (apex) → ❌ Not found
Strategy 4: Extract apex → curated.cx
  → Find site for curated.cx
  → Check subdomain_pattern_enabled → ✅ Enabled
Result: Site for curated.cx (via subdomain pattern)
```

### Unknown Domain
```
Request: unknown-domain.com
Strategy 1: Direct lookup → ❌ Not found
Strategy 2: www variant → ❌ Not found
Strategy 3: Apex variant → ❌ Not found
Strategy 4: Subdomain pattern → ❌ Not found
Strategy 5: Tenant fallback → ❌ Not found
Result: 404 → Domain Not Connected page
```

---

## Local Development

### Default Behavior

In development mode, special handling for localhost:

- `localhost` → resolves to root tenant's site
- `localhost:3000` → resolves to root tenant's site
- `subdomain.localhost` → resolves by tenant slug (e.g., `acme.localhost` → tenant with slug `acme`)

**Example**:
```ruby
# In development
Request: localhost
  → Development mode detected
  → Resolve to root tenant's site
Result: Root site

Request: acme.localhost
  → Development mode detected
  → Extract subdomain: "acme"
  → Find tenant with slug "acme"
  → Resolve to tenant's site
Result: Site for tenant with slug "acme"
```

### Override with ENV

You can override the default site for localhost:

```ruby
# config/environments/development.rb
config.default_localhost_site_slug = "acme"  # Optional
```

---

## Error Handling

### Unknown Domain

When no site is found for a hostname:

1. Middleware redirects to `/domain_not_connected`
2. `DomainNotConnectedController` displays error page
3. Error page shows the hostname and helpful message

**Response**:
- Status: `404 Not Found`
- Content: "Domain Not Connected" page with hostname
- Layout: Application layout (for consistent branding)

### Disabled Sites

Sites with `status: :disabled` are not accessible:

```
Request: disabled-site.example.com
  → Find site
  → Check status: disabled
  → Skip disabled site
  → Continue to next strategy
  → Not found → 404
```

---

## Domain Model

### Structure

```ruby
Domain
  - site_id (belongs_to :site)
  - hostname (unique, normalized)
  - primary (boolean, one per site)
  - verified (boolean)
  - verified_at (datetime)
```

### Hostname Normalization

Domains normalize hostnames before saving:

```ruby
domain = Domain.new(hostname: "EXAMPLE.COM:3000")
domain.valid?  # Normalizes to "example.com"
domain.hostname  # => "example.com"
```

### Finding Domains

Use normalized lookup:

```ruby
Domain.find_by_hostname!("Example.COM")  # Finds "example.com"
Domain.find_by_hostname!("example.com:3000")  # Finds "example.com"
```

---

## Best Practices

### 1. Register Both Apex and www

For best compatibility, register both variants:

```ruby
site = Site.find_by(slug: 'my-site')

# Primary domain (apex)
site.domains.create!(
  hostname: 'example.com',
  primary: true,
  verified: true
)

# www variant
site.domains.create!(
  hostname: 'www.example.com',
  primary: false,
  verified: true
)
```

### 2. Use Verified Domains Only

Always verify domains before making them active:

```ruby
domain = site.domains.find_by!(hostname: 'example.com')
domain.verify!  # Sets verified: true, verified_at: Time.current
```

### 3. Subdomain Patterns (Optional)

Enable subdomain patterns only when needed:

```ruby
# Enable for root site to allow ai.curated.cx, tech.curated.cx, etc.
root_site.update_setting("domains.subdomain_pattern_enabled", true)
```

---

## Testing

### Request Specs

Comprehensive tests in `spec/requests/domain_routing_spec.rb`:

```ruby
# Test apex domain
host! 'ainews.cx'
get root_path
expect(Current.site).to eq(site)

# Test www variant
host! 'www.ainews.cx'
get root_path
expect(Current.site).to eq(site)

# Test normalization
host! 'AiNeWs.Cx:3000'
get root_path
expect(Current.site).to eq(site)

# Test unknown domain
host! 'unknown.com'
get root_path
expect(response).to have_http_status(:not_found)
expect(response.body).to include('Domain Not Connected')
```

### Unit Tests

Domain normalization:

```ruby
normalized = Domain.normalize_hostname("EXAMPLE.COM:3000.")
expect(normalized).to eq("example.com")
```

---

## Migration Notes

### Existing Tenants

Existing tenants without Site/Domain structure will:

1. Fallback to tenant lookup
2. Auto-create default site and domain
3. Migrate seamlessly to new structure

**No action required** - backward compatibility is maintained.

### Data Migration

When migrating domains:

```ruby
# Create domain for existing tenant
tenant = Tenant.find_by!(hostname: 'example.com')
site = Site.find_by!(tenant: tenant)

site.domains.create!(
  hostname: tenant.hostname,
  primary: true,
  verified: true
)
```

---

## Summary

**Resolution Order**:
1. Direct hostname lookup
2. www → apex variant
3. Apex → www variant
4. Subdomain pattern (if enabled)
5. Tenant fallback (backward compatibility)

**Normalization**: Always lowercase, strip port, strip trailing dots

**Error Handling**: Unknown domains show "Domain Not Connected" page

**Local Dev**: Special localhost handling for development workflow

---

*Last Updated: 2025-01-20*
