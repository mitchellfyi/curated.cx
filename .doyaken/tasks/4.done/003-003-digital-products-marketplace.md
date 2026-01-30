# Task: Digital Products & Downloads Marketplace

## Metadata

| Field       | Value                                                  |
| ----------- | ------------------------------------------------------ |
| ID          | `003-003-digital-products-marketplace`                 |
| Status      | `done`                                                 |
| Priority    | `003` Medium                                           |
| Created     | `2026-01-30 15:30`                                     |
| Started     | `2026-01-30 22:15`                                     |
| Completed   | `2026-01-30 23:10`                                     |
| Blocked By  |                                                        |
| Blocks      |                                                        |
| Assigned To | `worker-1` |
| Assigned At | `2026-01-30 22:15` |

---

## Context

**Intent**: BUILD

### Problem Statement

Publishers cannot sell downloadable content (ebooks, templates, guides, code) through Curated. They must use external platforms like Gumroad, losing potential revenue and fragmenting their audience experience.

### Business Case

- **Competitive Feature**: beehiiv added digital products with zero commissions in Nov 2025. Kit (ConvertKit) lets creators sell digital products on the free plan. This is becoming standard.
- **Monetization**: Expands revenue options beyond subscriptions and listing fees.
- **Referral Synergy**: Digital products are ideal rewards for the existing referral program (ReferralRewardTier already has `digital_download` reward type).
- **RICE Score**: 108 (Reach: 600, Impact: 1.5, Confidence: 80%, Effort: 0.67 person-weeks)

### Technical Context

**Existing Infrastructure to Leverage:**

1. **Stripe Integration** - Full checkout flow exists via `StripeCheckoutService` and `StripeWebhookHandler`:
   - Creates Stripe Checkout sessions with metadata
   - Handles webhooks: `checkout.session.completed`, `checkout.session.expired`, `payment_intent.payment_failed`, `charge.refunded`
   - `PaymentReceiptMailer` for receipts
   - Routes: `/webhooks/stripe`, `/listings/:id/checkout`

2. **ActiveStorage** - Tables exist but unused. Storage configured for disk (dev) with S3 template ready.

3. **Multi-Tenant Architecture** - Uses `TenantScoped` and `SiteScoped` concerns with `Current.tenant`/`Current.site` context.

4. **Site Feature Flags** - JSONB config column with `setting("feature.enabled", default)` pattern.

5. **Admin Patterns** - `AdminAccess` concern, service classes, Pundit policies, Draper decorators.

6. **Referral Rewards** - `ReferralRewardTier` model already supports `digital_download` type with `reward_data["download_url"]`.

---

## Acceptance Criteria

All must be checked before moving to done:

### Core Models
- [x] `DigitalProduct` model with title, description, price_cents, status (draft/published/archived)
- [x] `DigitalProduct` uses ActiveStorage `has_one_attached :file` for product file
- [x] `DigitalProduct` uses `SiteScoped` concern (inherits tenant via site)
- [x] `DigitalProduct` supports free products (price_cents = 0)
- [x] `Purchase` model tracks user_id, digital_product_id, amount_cents, stripe_payment_intent_id
- [x] `DownloadToken` model for secure time-limited download links

### File Storage & Security
- [x] ActiveStorage configured for S3 in production (update storage.yml)
- [x] Signed URLs with 1-hour expiration for downloads
- [x] File type validation (PDF, ZIP, EPUB, MP3, MP4, PNG, JPG - max 500MB)
- [x] Download counter on products for analytics

### Payment Integration
- [x] `DigitalProductCheckoutService` creates Stripe sessions (extends existing pattern)
- [x] `StripeWebhookHandler` extended to handle digital product purchases
- [x] Purchase records created on successful payment
- [x] Download token generated and emailed after purchase
- [x] `DigitalProductMailer` sends product delivery email with download link

### Public Interface
- [x] Product listing page at `/products` (site-scoped)
- [x] Product detail page at `/products/:slug` with buy button
- [x] Checkout flow at `/products/:slug/checkout`
- [x] Download page at `/downloads/:token` (token-based, no login required)
- [x] Purchase history at `/my/purchases` (requires login)

### Admin Interface
- [x] Admin CRUD at `/admin/digital_products`
- [x] File upload with drag-and-drop
- [x] View purchases/downloads for each product
- [x] Sales dashboard with revenue, top products, download stats
- [x] Site config flag: `digital_products.enabled` (default: false)

### Referral Integration
- [x] Update `ReferralRewardTier` to reference `DigitalProduct` instead of just URL
- [x] When referral tier unlocked, auto-create Purchase record with $0 amount
- [x] Update `ReferralRewardService` to grant digital product access

### Tests
- [x] Model specs: DigitalProduct, Purchase, DownloadToken validations
- [x] Service specs: DigitalProductCheckoutService
- [x] Request specs: checkout flow, download authorization
- [x] Factory traits for paid/free products, purchases with/without payment

### Quality
- [x] Quality gates pass (RuboCop, Brakeman, RSpec)
- [x] No N+1 queries (Bullet) - includes() used in all controllers
- [x] Migrations are safe (StrongMigrations)
- [x] Changes committed with task reference

---

## Notes

**In Scope:**
- Single product file per DigitalProduct (v1 simplicity)
- One-time purchases only (no subscriptions)
- Stripe as sole payment provider
- Token-based downloads (no login required to download)
- Basic sales analytics (revenue, counts, downloads)

**Out of Scope:**
- Multiple files per product (bundle support) - future enhancement
- Product variants (different tiers/versions)
- Recurring subscriptions for products
- License key generation/DRM
- Affiliate commissions on products
- Product reviews/ratings
- Public product search/discovery across sites

**Assumptions:**
- S3 bucket will be configured before production deployment
- Stripe account is already connected (existing integration)
- Email delivery (via Action Mailer) is configured

**Edge Cases:**
| Case | Handling |
|------|----------|
| User buys same product twice | Allow (creates new Purchase, new download token) |
| Product deleted after purchase | Preserve purchase record, file remains in S3, existing tokens work |
| Product price changed | New purchases use new price, existing purchases unchanged |
| Download token expired | User can request new token from purchase history |
| File replaced on product | Existing tokens download new file |
| Free product (price = 0) | Skip Stripe, create Purchase immediately |
| Webhook arrives before redirect | Transaction-safe Purchase creation |

**Risks:**
| Risk | Impact | Mitigation |
|------|--------|------------|
| Large file uploads timeout | Users abandon | Chunked upload, progress indicator, generous timeout |
| S3 misconfiguration | Downloads fail | Validate config on deploy, fallback error messaging |
| Webhook signature mismatch | Purchases not recorded | Comprehensive logging, retry handling |
| Token sharing/abuse | Revenue loss | Short expiration (1hr), download limits (5 per token) |

---

## Plan

### Gap Analysis

| Criterion | Status | Gap |
|-----------|--------|-----|
| **Core Models** | | |
| `DigitalProduct` model with title, description, price_cents, status | none | Model doesn't exist, needs full creation |
| `DigitalProduct` uses ActiveStorage `has_one_attached :file` | none | ActiveStorage tables exist but no model attachments yet |
| `DigitalProduct` uses `SiteScoped` concern | none | Model doesn't exist |
| `DigitalProduct` supports free products (price_cents = 0) | none | Model doesn't exist |
| `Purchase` model with user_id, digital_product_id, amount_cents, stripe_payment_intent_id | none | Model doesn't exist |
| `DownloadToken` model for secure time-limited download links | none | Model doesn't exist |
| **File Storage & Security** | | |
| ActiveStorage configured for S3 in production | partial | Template exists in storage.yml but commented out |
| Signed URLs with 1-hour expiration for downloads | none | Needs implementation in DownloadsController |
| File type validation (PDF, ZIP, EPUB, MP3, MP4, PNG, JPG - max 500MB) | none | Needs custom validator |
| Download counter on products for analytics | none | Needs counter cache column |
| **Payment Integration** | | |
| `DigitalProductCheckoutService` creates Stripe sessions | none | Service doesn't exist; pattern available from `StripeCheckoutService` |
| `StripeWebhookHandler` extended for digital products | none | Handler exists, needs extension with new checkout_type routing |
| Purchase records created on successful payment | none | Logic needs to be added to webhook handler |
| Download token generated and emailed after purchase | none | Token generation + mailer needed |
| `PurchaseReceiptMailer` sends product delivery email | partial | `PaymentReceiptMailer` exists for listings; need new mailer for products |
| **Public Interface** | | |
| Product listing page at `/products` | none | Route, controller, view needed |
| Product detail page at `/products/:slug` | none | Route, controller, view needed |
| Checkout flow at `/products/:slug/checkout` | none | Route, controller needed; can follow listings checkout pattern |
| Download page at `/downloads/:token` | none | Route, controller, view needed |
| Purchase history at `/my/purchases` | none | Route, controller, view needed |
| **Admin Interface** | | |
| Admin CRUD at `/admin/digital_products` | none | Controller, service, views needed; pattern from `Admin::ListingsController` |
| File upload with drag-and-drop | none | View partial needed; Stimulus controller may help |
| View purchases/downloads for each product | none | Admin show view enhancements |
| Sales dashboard with revenue, top products, download stats | none | Query methods and view needed |
| Site config flag: `digital_products.enabled` | none | Add helper to Site model + config validation |
| **Referral Integration** | | |
| Update `ReferralRewardTier` to reference `DigitalProduct` | partial | Model has `digital_download` type but stores URL string, not FK |
| Auto-create Purchase record with $0 when tier unlocked | none | Logic needed in `ReferralRewardService` |
| Update `ReferralRewardService` to grant digital product access | none | Need to add product granting logic |
| **Tests** | | |
| Model specs for DigitalProduct, Purchase, DownloadToken | none | All specs needed |
| Service specs for DigitalProductCheckoutService | none | Spec needed |
| Request specs for checkout flow, download authorization | none | Specs needed |
| Factory traits for paid/free products, purchases | none | Factories needed |

### Risks

- [ ] **Large file upload timeouts**: Users may abandon uploads. Mitigation: Use direct-to-S3 uploads with progress indicator in future iteration; for v1, set generous server timeout.
- [ ] **S3 misconfiguration in production**: Downloads fail silently. Mitigation: Add health check for storage service; log blob service name on app boot.
- [ ] **Webhook race condition**: Webhook arrives before user redirect. Mitigation: Use transaction-safe Purchase creation; check for existing purchase before creating.
- [ ] **Token URL sharing**: Revenue loss from shared tokens. Mitigation: 1-hour expiration, max 5 downloads per token, log IP hashes.
- [ ] **Renaming mailer conflict**: `PurchaseReceiptMailer` vs existing `PaymentReceiptMailer`. Mitigation: Use distinct class name for digital product receipts.
- [ ] **Free product checkout bypass**: Must handle $0 purchases without Stripe. Mitigation: Create dedicated `handle_free_purchase` method.

### Steps

#### Phase 1: Core Models & Storage (Steps 1-5)

1. **Create DigitalProduct migration and model**
   - File: `db/migrate/YYYYMMDDHHMMSS_create_digital_products.rb`
   - Schema: `site_id:bigint`, `title:string`, `slug:string`, `description:text`, `price_cents:integer(default:0)`, `status:integer(default:0)`, `download_count:integer(default:0)`, `metadata:jsonb`
   - File: `app/models/digital_product.rb`
   - Include: `SiteScoped`, enum status, slug generation, validations
   - Verify: `rails db:migrate`, `DigitalProduct.new.valid?` shows validation errors

2. **Create Purchase migration and model**
   - File: `db/migrate/YYYYMMDDHHMMSS_create_purchases.rb`
   - Schema: `site_id:bigint`, `digital_product_id:bigint`, `user_id:bigint(nullable)`, `email:string`, `amount_cents:integer`, `stripe_payment_intent_id:string`, `stripe_checkout_session_id:string`, `purchased_at:datetime`, `source:integer(default:0)`
   - Indexes: unique on `stripe_checkout_session_id`, composite on `site_id,digital_product_id,email`
   - File: `app/models/purchase.rb`
   - Include: `SiteScoped`, associations, enum source (checkout/referral/admin_grant)
   - Verify: `rails db:migrate`, associations work

3. **Create DownloadToken migration and model**
   - File: `db/migrate/YYYYMMDDHHMMSS_create_download_tokens.rb`
   - Schema: `purchase_id:bigint`, `token:string(indexed unique)`, `expires_at:datetime`, `download_count:integer(default:0)`, `max_downloads:integer(default:5)`, `last_downloaded_at:datetime`
   - File: `app/models/download_token.rb`
   - Methods: `generate_token!`, `expired?`, `downloads_remaining`, `record_download!`
   - Verify: `rails db:migrate`, token generation works

4. **Configure ActiveStorage for S3**
   - File: `config/storage.yml` - uncomment and configure amazon service
   - File: `config/environments/production.rb` - set `config.active_storage.service = :amazon`
   - Note: S3 bucket + credentials must be set up separately
   - Verify: In dev, `ActiveStorage::Blob.service.name` returns `:local`

5. **Add file attachment and validations to DigitalProduct**
   - File: `app/models/digital_product.rb` - add `has_one_attached :file`
   - File: `app/validators/file_validator.rb` - create custom validator
   - Allowed types: `application/pdf`, `application/zip`, `application/epub+zip`, `audio/mpeg`, `video/mp4`, `image/png`, `image/jpeg`
   - Max size: 500MB
   - Verify: Invalid file type rejected, valid file attaches

#### Phase 2: Payment Integration (Steps 6-9)

6. **Create DigitalProductCheckoutService**
   - File: `app/services/digital_product_checkout_service.rb`
   - Initialize: `(digital_product, email:)`
   - Method: `create_session(success_url:, cancel_url:)` - creates Stripe session
   - Metadata: `checkout_type: "digital_product"`, `digital_product_id`, `site_id`, `purchaser_email`
   - Verify: `DigitalProductCheckoutService.new(product, email: "test@example.com").create_session(...)` returns session

7. **Handle free product purchases**
   - File: `app/services/digital_product_checkout_service.rb` - add `purchase_free!` method
   - Creates Purchase directly with `source: :checkout`, `amount_cents: 0`
   - Generates DownloadToken immediately
   - Returns Purchase instead of Stripe session
   - Verify: Free product creates purchase without Stripe

8. **Extend StripeWebhookHandler for digital products**
   - File: `app/services/stripe_webhook_handler.rb`
   - Modify: `handle_checkout_completed` to detect `checkout_type == "digital_product"`
   - Add: `handle_digital_product_purchase(session)` private method
   - Creates Purchase, DownloadToken, triggers `DigitalProductMailer.purchase_receipt`
   - Verify: Mock webhook event creates Purchase and DownloadToken

9. **Create DigitalProductMailer**
   - File: `app/mailers/digital_product_mailer.rb`
   - Method: `purchase_receipt(purchase)` - sends download link
   - File: `app/views/digital_product_mailer/purchase_receipt.html.erb`
   - File: `app/views/digital_product_mailer/purchase_receipt.text.erb`
   - Content: Product name, download link (token URL), expiration notice, support contact
   - Verify: Mailer preview at `/rails/mailers/digital_product_mailer/purchase_receipt`

#### Phase 3: Public Interface (Steps 10-14)

10. **Create routes for digital products**
    - File: `config/routes.rb`
    - Add: `resources :products, only: [:index, :show], controller: "digital_products"`
    - Add nested: `resource :checkout, only: [:create], controller: "product_checkouts" do get :success; get :cancel end`
    - Add: `get "downloads/:token", to: "downloads#show", as: :download`
    - Add: `namespace :my do resources :purchases, only: [:index, :show] end`
    - Verify: `rails routes | grep product` shows expected routes

11. **Create DigitalProductsController (public)**
    - File: `app/controllers/digital_products_controller.rb`
    - Actions: `index`, `show` (find by slug)
    - Guards: Check `Current.site.digital_products_enabled?`; 404 if disabled
    - File: `app/views/digital_products/index.html.erb` - product grid
    - File: `app/views/digital_products/show.html.erb` - detail with buy button
    - Verify: `/products` renders, `/products/my-product` renders

12. **Create ProductCheckoutsController**
    - File: `app/controllers/product_checkouts_controller.rb`
    - Action: `create` - uses `DigitalProductCheckoutService`
    - Free path: calls `purchase_free!`, redirects to success with purchase
    - Paid path: redirects to Stripe checkout URL
    - Actions: `success`, `cancel` - confirmation/retry pages
    - Verify: Free product checkout works end-to-end, paid redirects to Stripe

13. **Create DownloadsController**
    - File: `app/controllers/downloads_controller.rb`
    - Action: `show` - find by token, validate expiry/count, redirect to signed URL
    - Error handling: Expired token shows error page with option to request new token
    - Increment: `download_token.record_download!`
    - Security: Log IP hash for abuse detection
    - File: `app/views/downloads/expired.html.erb`
    - Verify: Valid token redirects to file, expired token shows error

14. **Create My::PurchasesController**
    - File: `app/controllers/my/purchases_controller.rb`
    - Guard: `authenticate_user!`
    - Action: `index` - list user's purchases with product info
    - Action: `show` - single purchase with regenerate token option
    - File: `app/views/my/purchases/index.html.erb`
    - File: `app/views/my/purchases/show.html.erb`
    - Verify: Logged-in user sees purchases, can regenerate download token

#### Phase 4: Admin Interface (Steps 15-19)

15. **Add site feature flag for digital products**
    - File: `app/models/site.rb` - add `digital_products_enabled?` method
    - Pattern: `setting("digital_products.enabled", false)`
    - Add config validation for `digital_products` key
    - Verify: `Site.first.digital_products_enabled?` returns false by default

16. **Create Admin::DigitalProductsController**
    - File: `app/controllers/admin/digital_products_controller.rb`
    - Include: `AdminAccess` concern
    - Actions: `index`, `show`, `new`, `create`, `edit`, `update`, `destroy`
    - File: `app/services/admin/digital_products_service.rb`
    - Methods: `all_products`, `find_product(id)`, `create_product(params)`, `update_product(id, params)`, `destroy_product(id)`
    - Verify: Admin can CRUD products

17. **Create admin routes**
    - File: `config/routes.rb` - add under `namespace :admin`
    - Add: `resources :digital_products`
    - Verify: `rails routes | grep admin.*digital` shows CRUD routes

18. **Create admin views**
    - File: `app/views/admin/digital_products/index.html.erb` - product list with stats
    - File: `app/views/admin/digital_products/show.html.erb` - detail with purchases list
    - File: `app/views/admin/digital_products/new.html.erb`
    - File: `app/views/admin/digital_products/edit.html.erb`
    - File: `app/views/admin/digital_products/_form.html.erb` - form with file upload
    - Verify: All admin views render

19. **Add sales dashboard to admin index**
    - File: `app/services/admin/digital_products_service.rb` - add `dashboard_stats` method
    - Metrics: Total revenue, total products (published/draft), total purchases, total downloads, top 5 products
    - File: `app/views/admin/digital_products/index.html.erb` - display stats at top
    - Verify: Dashboard shows correct numbers

#### Phase 5: Referral Integration (Steps 20-22)

20. **Add digital_product_id to ReferralRewardTier**
    - File: `db/migrate/YYYYMMDDHHMMSS_add_digital_product_to_referral_reward_tiers.rb`
    - Add: `digital_product_id:bigint(nullable)`, foreign key to digital_products
    - File: `app/models/referral_reward_tier.rb` - add `belongs_to :digital_product, optional: true`
    - Backward compat: Keep `download_url` method as fallback for URL-based rewards
    - Verify: `rails db:migrate`, can assign product to tier

21. **Update admin referral tier form**
    - File: `app/views/admin/referral_reward_tiers/_form.html.erb`
    - Add: Product dropdown when reward_type is `digital_download`
    - JavaScript: Show/hide based on reward type selection
    - Verify: Can select digital product in admin form

22. **Update ReferralRewardService to grant product access**
    - File: `app/services/referral_reward_service.rb`
    - Modify: `send_reward_email` method
    - When tier has `digital_product_id`: Create Purchase with `source: :referral`, `amount_cents: 0`; generate DownloadToken; send `DigitalProductMailer.purchase_receipt`
    - When tier has `download_url` only: Continue sending URL in email (backward compat)
    - Verify: Referral milestone unlock grants product access

#### Phase 6: Tests & Quality (Steps 23-27)

23. **Create factories**
    - File: `spec/factories/digital_products.rb`
    - Traits: `draft`, `published`, `archived`, `free`, `with_file`
    - File: `spec/factories/purchases.rb`
    - Traits: `from_checkout`, `from_referral`, `free_purchase`
    - File: `spec/factories/download_tokens.rb`
    - Traits: `expired`, `exhausted`
    - Verify: `FactoryBot.create(:digital_product, :published, :with_file)` works

24. **Write model specs**
    - File: `spec/models/digital_product_spec.rb`
    - Coverage: Validations, scopes, status enum, file attachment, slug generation
    - File: `spec/models/purchase_spec.rb`
    - Coverage: Validations, associations, source enum
    - File: `spec/models/download_token_spec.rb`
    - Coverage: Token generation, expiry checks, download counting
    - Verify: `bin/rspec spec/models/digital_product_spec.rb` passes

25. **Write service specs**
    - File: `spec/services/digital_product_checkout_service_spec.rb`
    - Coverage: Paid session creation, free purchase, Stripe errors
    - File: `spec/services/admin/digital_products_service_spec.rb`
    - Coverage: CRUD operations, dashboard stats
    - Verify: `bin/rspec spec/services/digital_product*` passes

26. **Write request specs**
    - File: `spec/requests/digital_products_spec.rb`
    - Coverage: Index, show, feature flag gate
    - File: `spec/requests/product_checkouts_spec.rb`
    - Coverage: Free checkout flow, paid checkout redirect, success/cancel
    - File: `spec/requests/downloads_spec.rb`
    - Coverage: Valid token download, expired token, exhausted token
    - File: `spec/requests/admin/digital_products_spec.rb`
    - Coverage: CRUD, file upload, authorization
    - Verify: `bin/rspec spec/requests/` passes

27. **Run quality gates and fix issues**
    - Run: `bin/rubocop --autocorrect`
    - Run: `bin/brakeman`
    - Run: `bin/rspec`
    - Fix: Any lint, security, or test failures
    - Verify: All quality gates pass

### Checkpoints

| After Step | Verify |
|------------|--------|
| Step 5 | Models exist, file attachment works: `DigitalProduct.create!(title: "Test", site: Site.first).file.attach(io: File.open("test.pdf"), filename: "test.pdf")` |
| Step 9 | Stripe integration works: Create product, checkout, receive webhook, purchase exists |
| Step 14 | Full public flow: Browse products, purchase, receive email, download file |
| Step 19 | Admin flow: Create product with file, view sales dashboard, see purchases |
| Step 22 | Referral integration: Set tier to product, unlock milestone, verify purchase created |
| Step 27 | Quality gates: `bin/quality` passes with no errors |

### Test Plan

- [ ] **Unit: DigitalProduct** - validations, scopes, attachment, slug uniqueness
- [ ] **Unit: Purchase** - validations, associations, amount_cents immutability
- [ ] **Unit: DownloadToken** - generation, expiry, download counting, max limit
- [ ] **Service: DigitalProductCheckoutService** - paid flow, free flow, Stripe API mock
- [ ] **Service: ReferralRewardService** - product grant on milestone
- [ ] **Request: Public products** - index, show, feature flag blocking
- [ ] **Request: Checkout** - free purchase, paid redirect, success callback
- [ ] **Request: Downloads** - valid token, expired, exhausted, IP logging
- [ ] **Request: Admin CRUD** - create with file, update, destroy, authorization
- [ ] **Integration: Webhook** - checkout.session.completed creates purchase + token + email

### Docs to Update

- [ ] `README.md` - Add digital products feature overview (if feature is documented)
- [ ] `AGENTS.md` - No changes needed (internal config)
- [ ] Admin help text in views - Add tooltips for file upload, pricing, status

---

## Work Log

### 2026-01-30 22:42 - Implementation Complete

**Phase 1: Core Models & Storage (Steps 1-5)**
- Created `DigitalProduct` model with SiteScoped, ActiveStorage attachment, slug generation
- Created `Purchase` model with stripe_checkout_session_id, stripe_payment_intent_id indexes
- Created `DownloadToken` model with token generation, expiry, download counting
- Configured ActiveStorage for S3 in production (falls back to local in dev)
- Added file validators: `FileContentTypeValidator`, `FileSizeValidator` (max 500MB)
- Files: 4 migrations, 3 models, 2 validators

**Phase 2: Payment Integration (Steps 6-9)**
- Created `DigitalProductCheckoutService` with paid/free purchase support
- Extended `StripeWebhookHandler` to route digital_product checkout_type
- Created `DigitalProductMailer` with purchase_receipt email and views
- Files: 2 services, 1 mailer, 2 mailer views

**Phase 3: Public Interface (Steps 10-14)**
- Added routes: `/products`, `/products/:slug`, `/products/:slug/checkout`, `/downloads/:token`, `/my/purchases`
- Created `DigitalProductsController` with feature flag check
- Created `ProductCheckoutsController` with free/paid checkout handling
- Created `DownloadsController` with token validation and signed URL redirect
- Created `My::PurchasesController` with purchase history and token regeneration
- Files: 4 controllers, 12 views

**Phase 4: Admin Interface (Steps 15-19)**
- Added `digital_products_enabled?` to Site model with config validation
- Created `Admin::DigitalProductsController` with CRUD
- Created `Admin::DigitalProductsService` with dashboard_stats
- Created admin views with sales dashboard
- Files: 1 controller, 1 service, 5 views

**Phase 5: Referral Integration (Steps 20-22)**
- Added `digital_product_id` to `ReferralRewardTier` via migration
- Updated referral tier form with digital product dropdown
- Updated `ReferralRewardService.grant_digital_product` to create Purchase + DownloadToken
- Files: 1 migration, modified 3 files

**Quality Checks:**
- RuboCop: All files pass (0 offenses)
- Brakeman: 1 weak warning (intentional redirect to signed S3 URL)
- Models load and validate correctly

**Statistics:**
- New files: 28
- Modified files: 8
- Migrations: 4
- Lines added: ~1500

### 2026-01-30 22:45 - Planning Complete

**Codebase Analysis:**
- Reviewed `StripeCheckoutService` (152 lines) and `StripeWebhookHandler` (148 lines) - patterns are clear and extensible
- Confirmed `SiteScoped` concern is the correct isolation pattern (not TenantScoped directly)
- `ReferralRewardTier` has `digital_download` type but stores URL string, needs FK addition
- ActiveStorage tables exist, no models use attachments yet - first usage
- `Site.rb` feature flag pattern: `setting("feature.enabled", default)` with JSONB validation

**Gap Analysis Summary:**
- 23 of 23 acceptance criteria need implementation (none exist)
- 3 partial items: S3 config (templated), mailer pattern (PaymentReceiptMailer exists), referral tier (type exists)
- Critical pattern references: `StripeCheckoutService:75-85`, `StripeWebhookHandler:41-69`, `Site.rb:99-100`

**Plan Statistics:**
- Steps: 27 (across 6 phases)
- New files: ~25
- Modified files: ~6 (routes.rb, stripe_webhook_handler.rb, referral_reward_service.rb, referral_reward_tier.rb, site.rb, admin referral form)
- Migrations: 4 (digital_products, purchases, download_tokens, add_digital_product_to_referral_reward_tiers)
- Risks: 6 identified with mitigations

**Key Decisions:**
- Use `SiteScoped` not `TenantScoped` (site is primary isolation boundary)
- Create new `DigitalProductMailer` vs extending `PaymentReceiptMailer` (separation of concerns)
- Keep `download_url` backward compat in ReferralRewardTier (gradual migration)
- Token-based downloads with 1hr expiry, max 5 downloads per token
- Free products handled inline (no Stripe for $0)

---

### 2026-01-30 22:20 - Triage Complete

Quality gates:
- Lint: `bundle exec rubocop` (via bin/quality)
- Types: N/A (Ruby - no static types)
- Tests: `bundle exec rspec` (via bin/quality)
- Build: `bin/quality` (comprehensive quality script)

Task validation:
- Context: clear - well-documented existing infrastructure (Stripe, ActiveStorage, multi-tenant)
- Criteria: specific - 40+ acceptance criteria with checkboxes, clear scope boundaries
- Dependencies: satisfied - StripeCheckoutService, StripeWebhookHandler, ReferralRewardTier all exist

Complexity:
- Files: many (~30 new/modified per plan)
- Risk: medium - leverages existing patterns, but large surface area

Infrastructure verified:
- ✅ `app/services/stripe_checkout_service.rb` - Stripe session creation pattern exists
- ✅ `app/services/stripe_webhook_handler.rb` - webhook handling exists
- ✅ `app/models/referral_reward_tier.rb` - has `digital_download` reward type
- ✅ `config/storage.yml` - S3 template ready (currently commented out)
- ✅ Stripe gem installed (`stripe`, `~> 13.0`)
- ✅ ActiveStorage + image_processing gems available

Risks flagged:
- `manifest.yaml` quality commands are empty (using bin/quality script instead)
- S3 config commented out - needs uncommenting for production

Ready: yes

---

### 2026-01-30 22:15 - Task Expanded

- Intent: BUILD
- Scope: Full digital products marketplace with Stripe checkout, secure downloads, admin management
- Key files to create:
  - Models: `digital_product.rb`, `purchase.rb`, `download_token.rb`
  - Services: `digital_product_checkout_service.rb`
  - Controllers: `digital_products_controller.rb`, `downloads_controller.rb`, `admin/digital_products_controller.rb`
  - Migrations: 3-4 new tables
- Key files to modify:
  - `app/services/stripe_webhook_handler.rb` - add digital product handling
  - `app/services/referral_reward_service.rb` - grant product on tier unlock
  - `app/models/referral_reward_tier.rb` - add product association
  - `app/models/site.rb` - add feature flag helper
  - `config/routes.rb` - add routes
  - `config/storage.yml` - add S3 config
- Complexity: Medium-High (leverages existing patterns but significant surface area)
- Estimated files: ~30 new/modified files
- Existing patterns to follow:
  - `StripeCheckoutService` for payment service
  - `Admin::ListingsController` for admin CRUD
  - `ReferralRewardTier` for site-scoped JSONB models

---

## Testing Evidence

### 2026-01-30 22:58 - Testing Complete

Tests written:
- `spec/factories/digital_products.rb` - Factory with traits (draft, published, archived, free, with_file)
- `spec/factories/purchases.rb` - Factory with traits (from_checkout, from_referral, admin_grant, free_purchase)
- `spec/factories/download_tokens.rb` - Factory with traits (expired, exhausted, fresh, used_once)
- `spec/models/digital_product_spec.rb` - 42 tests (validations, scopes, callbacks, methods)
- `spec/models/purchase_spec.rb` - 31 tests (validations, associations, enums, scopes)
- `spec/models/download_token_spec.rb` - 37 tests (token generation, expiry, download counting)
- `spec/services/digital_product_checkout_service_spec.rb` - 17 tests (Stripe sessions, free purchases)
- `spec/services/admin/digital_products_service_spec.rb` - 21 tests (CRUD, dashboard stats)
- `spec/requests/digital_products_spec.rb` - 17 tests (index, show, feature flag, site isolation)
- `spec/requests/product_checkouts_spec.rb` - 12 tests (free/paid checkout, success/cancel)
- `spec/requests/downloads_spec.rb` - 13 tests (valid/expired/exhausted tokens, 404 handling)

Quality gates:
- Lint: pass (0 offenses)
- Types: N/A (Ruby)
- Tests: pass (3523 total, 190 new)
- Build: pass
- Security: 1 weak warning (intentional redirect to signed S3 URL)

CI ready: yes

Bugs found and fixed during testing:
- Added `skip_after_action :verify_authorized` and `skip_after_action :verify_policy_scoped` to public controllers (Pundit)

---

### 2026-01-30 23:10 - Review Complete

**Findings:**
- Blockers: 1 - fixed
  - `My::PurchasesController` missing `skip_after_action :verify_authorized` and `skip_after_action :verify_policy_scoped` - would cause Pundit authorization errors
- High: 0
- Medium: 0
- Low: 0

**Review passes:**
- Correctness: pass - all happy paths and edge cases traced
- Design: pass - follows existing patterns (SiteScoped, AdminAccess, service classes)
- Security: pass - proper token-based auth for downloads, admin RBAC, no SQL injection, signed S3 URLs
- Performance: pass - includes() used appropriately, no N+1, idempotent webhook handling
- Tests: pass - 213 examples, 0 failures covering models, services, and request specs

**Fixes applied:**
1. Added `skip_after_action :verify_authorized` and `skip_after_action :verify_policy_scoped` to `My::PurchasesController`

**All criteria met:** yes

**Follow-up tasks:** none

**Status:** COMPLETE

---

### 2026-01-30 23:01 - Documentation Sync

Docs updated:
- `README.md` - Added `DigitalProductCheckoutService` to Key Services table

Inline comments:
- Already present in implementation (no additions needed)

Admin help text verified:
- `app/views/admin/digital_products/_form.html.erb` - Has slug hint, price hint (cents format), file types hint (500MB max)
- `app/views/admin/referral_reward_tiers/_form.html.erb` - Has digital product help text for referral integration

I18n translations verified:
- `config/locales/en.yml` - 60+ keys for digital products admin section

Consistency: verified - code and docs aligned

---

## Links

- Research: beehiiv digital products, Gumroad, ConvertKit commerce
- Related code:
  - `app/services/stripe_checkout_service.rb` - existing Stripe pattern
  - `app/services/stripe_webhook_handler.rb` - webhook handling
  - `app/models/referral_reward_tier.rb` - has digital_download type
  - `app/controllers/admin/listings_controller.rb` - admin CRUD pattern
