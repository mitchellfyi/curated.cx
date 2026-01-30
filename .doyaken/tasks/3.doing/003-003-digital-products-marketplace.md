# Task: Digital Products & Downloads Marketplace

## Metadata

| Field       | Value                                                  |
| ----------- | ------------------------------------------------------ |
| ID          | `003-003-digital-products-marketplace`                 |
| Status      | `todo`                                                 |
| Priority    | `003` Medium                                           |
| Created     | `2026-01-30 15:30`                                     |
| Started     |                                                        |
| Completed   |                                                        |
| Blocked By  |                                                        |
| Blocks      |                                                        |
| Assigned To | `worker-1` |
| Assigned At | `2026-01-30 22:15` |

---

## Context

Why does this task exist? What problem does it solve?

- **Competitive Feature**: beehiiv added digital products with zero commissions in Nov 2025. Kit (ConvertKit) lets creators sell digital products on the free plan. This is becoming standard.
- **Monetization**: Expands revenue options beyond subscriptions and listing fees.
- **Referral Synergy**: Digital products are ideal rewards for the referral program.
- **RICE Score**: 108 (Reach: 600, Impact: 1.5, Confidence: 80%, Effort: 0.67 person-weeks)

**Problem**: Publishers cannot sell downloadable content (ebooks, templates, guides) through Curated. They must use external platforms like Gumroad.

**Solution**: A simple digital products feature allowing publishers to upload files and sell them with Stripe checkout.

---

## Acceptance Criteria

All must be checked before moving to done:

- [ ] DigitalProduct model with file attachment
- [ ] Secure file storage (ActiveStorage with signed URLs)
- [ ] Stripe checkout integration for purchases
- [ ] Download page with expiring links
- [ ] Purchase history for users
- [ ] Product listing on site
- [ ] Free products (for referral rewards)
- [ ] Sales analytics dashboard
- [ ] Tests written and passing
- [ ] Quality gates pass
- [ ] Changes committed with task reference

---

## Plan

Step-by-step implementation approach:

1. **Step 1**: Create DigitalProduct model
   - Files: `app/models/digital_product.rb`, `db/migrate/xxx_create_digital_products.rb`
   - Actions: name, description, price_cents, site_id, file attachment

2. **Step 2**: Create Purchase model
   - Files: `app/models/purchase.rb`
   - Actions: user_id, digital_product_id, amount_cents, stripe_payment_id

3. **Step 3**: Create product pages
   - Files: `app/controllers/digital_products_controller.rb`, views
   - Actions: Product listing, detail page, checkout button

4. **Step 4**: Integrate Stripe checkout
   - Files: Extend existing Stripe integration
   - Actions: Create checkout session, handle webhooks

5. **Step 5**: Create download delivery
   - Files: `app/controllers/downloads_controller.rb`
   - Actions: Signed URLs, expiring links, download tracking

6. **Step 6**: Create admin management
   - Files: `app/controllers/admin/digital_products_controller.rb`
   - Actions: CRUD, upload files, view sales

7. **Step 7**: Add sales dashboard
   - Files: Admin views
   - Actions: Revenue, downloads, popular products

8. **Step 8**: Write tests
   - Files: `spec/models/digital_product_spec.rb`, `spec/features/purchase_spec.rb`
   - Coverage: Upload, purchase, download, security

---

## Work Log

_No work started yet._

---

## Testing Evidence

_No tests run yet._

---

## Notes

- Use existing Stripe integration (already has checkout flow for listings)
- ActiveStorage for file uploads with S3 backend
- Signed URLs with short expiration for security
- Support PDF, ZIP, common document formats
- Consider download limits to prevent sharing

---

## Links

- Research: beehiiv digital products, Gumroad
- Related: Existing Stripe integration, Listing checkout flow
