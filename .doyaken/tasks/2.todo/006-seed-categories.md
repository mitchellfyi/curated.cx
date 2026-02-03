# Seed Categories for Each Tenant

## Description

Create standard category records for each tenant site to organize listings (tools, jobs, services, etc.)

## Acceptance Criteria

- [ ] Create categories for ainews.cx
- [ ] Create categories for construction.cx
- [ ] Create categories for dayz.cx
- [ ] Configure shown_fields per category type

## Categories Per Tenant

**All tenants (standard):**
- `tools` - Tools & Apps
- `jobs` - Job Listings
- `services` - Services & Agencies
- `events` - Events & Conferences

**ainews.cx specific:**
- `models` - AI Models
- `datasets` - Datasets
- `research` - Research Papers

**construction.cx specific:**
- `suppliers` - Material Suppliers
- `contractors` - Contractors
- `equipment` - Equipment

**dayz.cx specific:**
- `servers` - Game Servers
- `mods` - Mods & Add-ons
- `guides` - Guides & Tutorials

## Seed Template

```ruby
Category.create!(
  site: site,
  tenant: tenant,
  key: "tools",
  name: "Tools & Apps",
  allow_paths: true,
  shown_fields: {
    image_url: true,
    description: true,
    company: true,
    domain: true
  }
)
```

## Priority

medium

## Labels

feature, setup
