# Security - Tenant & Site Isolation Guarantee

## Overview

Curated.cx implements strict site-level isolation to ensure that content, listings, categories, and all other tenant-scoped data never leaks across Sites, even when Sites belong to the same Tenant.

**Core Principle**: Each domain is its own micro-network. Site A cannot access Site B's content, even if they share the same Tenant (owner account).

---

## Scoping Boundary

### Site-Level Scoping (Primary Isolation)

**Most records scope to Site** (not just Tenant):

- `Category` - scoped to `site_id`
- `Listing` - scoped to `site_id`
- `Vote` - scoped to `site_id`
- `Comment` - scoped to `site_id`
- `SiteBan` - scoped to `site_id`
- `ContentItem` - scoped to `site_id`

### Tenant-Level Access

**Tenant** represents the owner account and can:
- Own multiple Sites
- Manage all their Sites via admin interface
- Share authentication across Sites (future)

But **cannot** access cross-site content in normal operations due to site-level scoping.

---

## Implementation

### Current Context Pattern

The application uses `Current.site` for request-scoped site context:

```ruby
# Set by TenantResolver middleware based on request hostname
Current.site = Site.find_by_hostname!("example.com")

# Tenant is derived from site for backward compatibility
Current.tenant # => site.tenant
```

### SiteScoped Concern

All site-scoped models include the `SiteScoped` concern:

```ruby
class Listing < ApplicationRecord
  include SiteScoped  # Automatically scopes to Current.site

  belongs_to :site
  validates :site, presence: true
end
```

**Default Scope Behavior**:
```ruby
# Automatic scoping when Current.site is set
default_scope { where(site: Current.site) if Current.site }

# All queries are automatically scoped
Listing.all  # Only returns listings for Current.site

# Explicit unscoped queries require explicit call
Listing.without_site_scope  # Returns all listings (admin/system use)
```

### Tenant/Site Consistency

The `SiteScoped` concern also ensures tenant/site consistency for models that include both `SiteScoped` and `TenantScoped`:

**Automatic Tenant Assignment**:
```ruby
# On create, tenant is automatically set from site (if not already set)
before_validation :set_tenant_from_site, on: :create

# This allows simplified record creation:
Listing.create!(site: current_site, title: "Article")
# tenant is automatically set to current_site.tenant
```

**Consistency Validation**:
```ruby
# Validates that tenant matches site's tenant
validate :ensure_site_tenant_consistency

# This catches edge cases like:
# - Data migrations that set tenant directly
# - Console operations with incorrect setup
# - API imports with explicit (wrong) tenant setting
```

**Example**:
```ruby
site = Site.find_by(slug: 'ai-news')  # site.tenant = acme_corp
wrong_tenant = Tenant.find_by(slug: 'other-corp')

# This will fail validation:
listing = Listing.new(site: site, tenant: wrong_tenant, title: "Article")
listing.valid?  # => false
listing.errors[:site]  # => ["must belong to the same tenant"]
```

---

## Isolation Guarantee Examples

### Example 1: Two Sites, One Tenant

**Scenario**:
- Tenant: "ACME Corp" (slug: `acme-corp`)
- Site A: "AI News" (domain: `ainews.example.com`, slug: `ai-news`)
- Site B: "Tech News" (domain: `tech.example.com`, slug: `tech-news`)

**Data**:
- Site A has 10 listings
- Site B has 15 listings

**Guarantee**:
```ruby
# When accessing ainews.example.com
Current.site = Site.find_by(slug: 'ai-news')
Listing.all  # Returns only 10 listings from Site A

# When accessing tech.example.com
Current.site = Site.find_by(slug: 'tech-news')
Listing.all  # Returns only 15 listings from Site B

# Cross-site access is impossible
host! 'ainews.example.com'
get listing_path(site_b_listing)  # Returns 404 Not Found
```

### Example 2: Category Isolation

```ruby
# Site A creates a category
site_a = Site.find_by(slug: 'ai-news')
Current.site = site_a
category_a = Category.create!(key: 'news', name: 'News', site: site_a)

# Site B creates a category with same key (allowed!)
site_b = Site.find_by(slug: 'tech-news')
Current.site = site_b
category_b = Category.create!(key: 'news', name: 'News', site: site_b)

# Uniqueness is scoped to site
category_a.key == category_b.key  # => true (allowed!)
category_a.site != category_b.site  # => true (different sites)

# Site A cannot access Site B's category
Current.site = site_a
Category.find_by(key: 'news')  # Returns only category_a
Category.find(category_b.id)   # Raises ActiveRecord::RecordNotFound
```

### Example 3: Listing URL Uniqueness

```ruby
# Listing URLs are unique per site, not globally
site_a = Site.find_by(slug: 'ai-news')
site_b = Site.find_by(slug: 'tech-news')

Current.site = site_a
listing_a = Listing.create!(
  url_canonical: 'https://example.com/article',
  title: 'Article A',
  category: category_a,
  site: site_a
)

Current.site = site_b
listing_b = Listing.create!(
  url_canonical: 'https://example.com/article',  # Same URL!
  title: 'Article B',
  category: category_b,
  site: site_b
)

# Both listings exist with same URL - uniqueness is scoped to site
listing_a.url_canonical == listing_b.url_canonical  # => true
listing_a.site != listing_b.site  # => true (different sites)
```

---

## Request Specs

Request specs prove isolation at the HTTP layer:

```ruby
# spec/requests/site_isolation_spec.rb
describe "Site Isolation" do
  let!(:tenant) { create(:tenant) }
  let!(:site_a) { create(:site, tenant: tenant) }
  let!(:site_b) { create(:site, tenant: tenant) }
  let!(:listing_a) { create(:listing, site: site_a) }
  let!(:listing_b) { create(:listing, site: site_b) }

  it "Site A cannot access Site B content" do
    host! 'sitea.example.com'
    get listing_path(listing_b)
    expect(response).to have_http_status(:not_found)
  end
end
```

**Run the tests**:
```bash
bundle exec rspec spec/requests/site_isolation_spec.rb
```

---

## Security Considerations

### Default Scopes

Default scopes enforce isolation automatically:
- ✅ All queries are scoped by default
- ✅ Cross-site access is impossible via normal queries
- ✅ Explicit `without_site_scope` is required for admin operations

### Controller Authorization

Controllers use Pundit policies that respect site scoping:

```ruby
class ListingsController < ApplicationController
  def show
    # Policy scope automatically respects Current.site
    @listing = policy_scope(Listing).find(params[:id])
    authorize @listing
  end
end
```

### Background Jobs

Background jobs must explicitly set `Current.site`:

```ruby
class ProcessListingJob < ApplicationJob
  def perform(listing_id)
    listing = Listing.without_site_scope.find(listing_id)
    Current.site = listing.site
    # Now scoped queries work correctly
    listing.process!
  end
end
```

---

## Testing Isolation

### Manual Testing

1. Create two sites under one tenant
2. Create content in each site
3. Access Site A via its domain - verify only Site A content is visible
4. Access Site B via its domain - verify only Site B content is visible
5. Attempt cross-site access - verify 404 responses

### Automated Testing

Request specs in `spec/requests/site_isolation_spec.rb`:
- ✅ Prove Site A cannot access Site B content
- ✅ Prove Site B cannot access Site A content
- ✅ Verify Current.site is set correctly
- ✅ Verify default scopes enforce isolation

---

## Migration Notes

### Backward Compatibility

The system maintains backward compatibility:
- `Current.tenant` still works (derived from `Current.site`)
- Models keep `tenant_id` for data access
- `TenantScoped` concern is deprecated in favor of `SiteScoped`

### Data Migration

When migrating existing data:
1. Sites are created from existing Tenants
2. Primary domains are created from Tenant hostnames
3. Categories and Listings are assigned to Sites
4. All new records use site-level scoping

---

## Summary

**Isolation Guarantee**: Content never leaks across Sites, even when Sites share the same Tenant.

**Mechanism**:
- Site-level default scopes via `SiteScoped` concern
- `Current.site` set by `TenantResolver` middleware
- All queries automatically scoped unless explicitly unscoped

**Testing**: Request specs prove isolation at the HTTP layer.

**Security**: Default scopes + Pundit policies ensure no cross-site access is possible.

---

*Last Updated: 2026-01-23*
