# Add Weekly Email Digest

**Priority:** Medium
**Suggested by:** kell-suggested (auto-generated)

## Overview

Add a weekly email digest feature that sends subscribers a summary of the best content from their subscribed tenant sites.

## Requirements

1. **Subscriber Model**
   - Add `email_subscribers` table (email, tenant_id, confirmed_at, unsubscribed_at)
   - Add subscription confirmation flow (double opt-in)
   - Add unsubscribe link/flow

2. **Digest Job**
   - Create `SendWeeklyDigestJob` that runs weekly
   - Query top content from past week (by engagement/freshness)
   - Generate digest email with 5-10 top items per tenant

3. **Email Template**
   - Clean, responsive email template
   - Per-tenant branding (logo, colors)
   - Links to full articles
   - Prominent unsubscribe link

4. **Admin UI**
   - View subscriber count per tenant
   - Manual trigger for digest send (testing)
   - View digest send history

## Acceptance Criteria

- [ ] Users can subscribe to email digest from tenant site
- [ ] Double opt-in confirmation email works
- [ ] Weekly digest job runs and sends emails
- [ ] Unsubscribe works and is tracked
- [ ] Admin can see subscriber metrics

## Notes

This enhances the content network by keeping users engaged between visits. Standard feature for content platforms.
