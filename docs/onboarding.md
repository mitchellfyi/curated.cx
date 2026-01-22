# Onboarding Flow - Site and Domain Setup

## Overview

The onboarding flow allows signed-in tenants to create new sites and connect domains. This document describes the user experience and what to expect at each step.

---

## User Flow

### Step 1: Create a New Site

**Access**: Navigate to `/admin/sites` and click "New Site"

**Required Information**:
- **Name**: Display name for the site (e.g., "AI News")
- **Slug**: URL-friendly identifier (lowercase letters, numbers, underscores only)
- **Description**: Optional brief description
- **Topic Tags**: Comma-separated list of topics (e.g., "ai, machine-learning, technology")

**What Happens**:
1. Site is created and associated with the current tenant
2. Topics are stored in the site's JSONB config
3. User is redirected to the site's detail page

**Validation**:
- Name and slug are required
- Slug must be unique per tenant
- Slug must match format: `[a-z0-9_]+`

---

### Step 2: Add a Domain

**Access**: From the site detail page, click "Add Domain"

**Required Information**:
- **Domain**: Hostname (e.g., `example.com` or `news.example.com`)
- **Primary**: Checkbox to set as primary domain (only one per site)

**What Happens**:
1. Domain is normalized (lowercase, port stripped, trailing dots removed)
2. Domain is validated for format and uniqueness
3. First domain added is automatically set as primary
4. User is redirected to domain detail page with DNS instructions

**Validation**:
- Hostname must be valid domain format
- Hostname must be unique across all domains
- Only one primary domain allowed per site

---

### Step 3: Configure DNS

**Access**: Domain detail page shows DNS configuration instructions

**DNS Instructions by Domain Type**:

#### Apex Domain (e.g., `example.com`)

**A Record**:
```
Type: A
Name: @
Value: [VPS IP or canonical hostname]
TTL: 3600 (1 hour) or provider default
```

**ALIAS/ANAME Record (Alternative)**:
```
Type: ALIAS/ANAME
Name: @
Value: [VPS IP or canonical hostname]
```

**Notes**:
- A records point directly to an IP address
- ALIAS/ANAME records point to a hostname (preferred if supported)
- Some providers require A records only

#### Subdomain (e.g., `news.example.com`)

**CNAME Record**:
```
Type: CNAME
Name: news
Value: [VPS IP or canonical hostname]
TTL: 3600 (1 hour) or provider default
```

**Notes**:
- CNAME records point to a hostname, not an IP address
- TTL of 3600 seconds (1 hour) is recommended for faster propagation
- Some DNS providers may require lower TTL for subdomains

---

### Step 4: Check DNS Configuration

**Access**: Click "Check DNS" button on domain detail page

**What Happens**:
1. System queries DNS records for the domain
2. Results are displayed:
   - **Green**: DNS records found and correct
   - **Yellow**: No DNS records found (may need time to propagate)
   - **Red**: Error querying DNS

**Note**: DNS propagation can take up to 48 hours. The check may show "no records found" even if DNS is configured correctly.

---

## Configuration

### DNS Target

The DNS target (VPS IP or canonical hostname) is configurable via environment variable:

```bash
DNS_TARGET=curated.cx  # Default
# or
DNS_TARGET=192.168.1.100  # VPS IP address
```

Set this in your deployment environment or `.env` file.

---

## User Experience

### Site List Page (`/admin/sites`)

- Shows all sites for the current tenant
- Displays site name, status, description, and domain count
- Shows topic tags as badges
- "New Site" button to create a new site

### Site Detail Page (`/admin/sites/:id`)

- Shows site information and topic tags
- Lists all domains for the site
- "Add Domain" button to connect a new domain
- Each domain shows verification status

### Domain Detail Page (`/admin/sites/:site_id/domains/:id`)

- Shows domain hostname and status (primary, verified)
- Displays DNS configuration instructions
- "Check DNS" button to verify DNS setup
- Shows DNS check results when available

---

## Expected Behavior

### Creating a Site

1. Fill in site form with name, slug, description, and topics
2. Submit form
3. Site is created and associated with tenant
4. Redirected to site detail page
5. Site appears in sites list

### Adding a Domain

1. Navigate to site detail page
2. Click "Add Domain"
3. Enter hostname (apex or subdomain)
4. Submit form
5. Domain is created and normalized
6. Redirected to domain detail page with DNS instructions

### DNS Instructions

- **Apex domains** show A record and ALIAS/ANAME options
- **Subdomains** show CNAME record configuration
- Instructions are tailored to domain type
- TTL guidance is provided

### DNS Check

- Queries DNS records for the domain
- Shows results immediately (no background job)
- May show "no records found" if DNS hasn't propagated yet
- Provides helpful error messages if DNS query fails

---

## Troubleshooting

### "Domain already exists" Error

- Each hostname must be unique across all sites
- Check if domain is already connected to another site
- Use a different hostname or contact support

### "Invalid hostname format" Error

- Hostname must be valid domain format
- Remove any ports, protocols, or paths
- Use lowercase (will be normalized automatically)

### DNS Check Shows "No Records Found"

- DNS propagation can take up to 48 hours
- Verify DNS settings in your DNS provider
- Ensure DNS records are configured correctly
- Wait a few hours and check again

### DNS Check Fails with Error

- DNS query may be blocked by firewall
- DNS server may be unreachable
- Check network connectivity
- Try again later

---

## Technical Details

### Domain Normalization

All hostnames are normalized before storage:
- Lowercase conversion
- Port removal (e.g., `example.com:3000` → `example.com`)
- Trailing dot removal (e.g., `example.com.` → `example.com`)

### Primary Domain

- First domain added to a site is automatically set as primary
- Only one domain can be primary per site
- Primary domain is used for canonical URLs

### DNS Target Configuration

The DNS target is determined by:
1. `DNS_TARGET` environment variable (if set)
2. Default: `curated.cx`

This allows flexibility between:
- VPS IP address (for A records)
- Canonical hostname (for CNAME/ALIAS records)

---

## Future Enhancements

- Background DNS verification job
- Automatic domain verification when DNS is correct
- Email notifications when domain is verified
- Bulk domain import
- Domain transfer between sites

---

*Last Updated: 2025-01-20*
