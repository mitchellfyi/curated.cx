# Anti-Pattern Prevention Documentation

## Overview

This document defines the anti-patterns, shortcuts, and workarounds that are **ABSOLUTELY FORBIDDEN** in the Curated.www codebase. The goal is to ensure that AI agents and developers implement solutions properly, following project goals and best practices, rather than taking shortcuts to complete tasks or make tests pass.

## Core Philosophy: No Shortcuts

**"Simple, Clear, Elegant, Boring, Best Practice"**

- **Simple**: Direct solutions without unnecessary complexity
- **Clear**: Code intention is immediately obvious
- **Elegant**: Minimal, well-structured implementations
- **Boring**: Proven patterns over clever hacks
- **Best Practice**: Industry-standard approaches

## Forbidden Anti-Patterns

### 1. Quality Tool Bypasses (CRITICAL - FORBIDDEN)

#### ❌ **NEVER ALLOWED**:
```ruby
# rubocop:disable Style/StringLiterals
def bad_method
  return 'hardcoded string'  # This bypasses quality checks
end
# rubocop:enable Style/StringLiterals

# Other forbidden bypasses:
safety_assured do
  # Bypassing Strong Migrations
end

rescue => e
  # Silently ignoring errors - FORBIDDEN
end
```

#### ✅ **CORRECT APPROACH**:
```ruby
def proper_method
  t('models.example.message')  # Use i18n properly
end

# Fix migration safety issues by following proper patterns
class SafeMigration < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :listings, :status, algorithm: :concurrently
  end
end
```

### 2. Multi-Tenant Anti-Patterns (CRITICAL)

#### ❌ **SHORTCUTS TO AVOID**:
```ruby
# Manual tenant scoping instead of acts_as_tenant
class Listing < ApplicationRecord
  scope :for_tenant, ->(tenant) { where(tenant_id: tenant.id) }

  def self.current_tenant_listings
    where(tenant_id: Current.tenant.id)  # Manual scoping
  end
end

# Direct database calls in controllers
class ListingsController < ApplicationController
  def index
    @listings = Listing.where(tenant_id: current_tenant.id)  # WRONG
  end
end
```

#### ✅ **PROPER IMPLEMENTATION**:
```ruby
# Use acts_as_tenant for automatic scoping
class Listing < ApplicationRecord
  acts_as_tenant :tenant

  # Scoping is automatic - no manual tenant_id checks needed
end

# Use Current.tenant for proper scoping
class ListingsController < ApplicationController
  def index
    @listings = Current.tenant.listings.published  # CORRECT
  end
end
```

### 3. i18n Anti-Patterns (CRITICAL)

#### ❌ **HARDCODED STRINGS (NEVER ALLOWED)**:
```erb
<!-- FORBIDDEN: Hardcoded strings -->
<h1>Welcome to our platform</h1>
<%= link_to "Edit", edit_path %>
<%= form.text_field :title, placeholder: "Enter title here" %>

<!-- FORBIDDEN: English-only content -->
<div class="alert">Your changes have been saved successfully</div>
```

#### ✅ **PROPER i18n IMPLEMENTATION**:
```erb
<!-- CORRECT: Always use i18n keys -->
<h1><%= t('welcome.title') %></h1>
<%= link_to t('actions.edit'), edit_path %>
<%= form.text_field :title, placeholder: t('forms.title.placeholder') %>

<!-- CORRECT: All user-facing text internationalized -->
<div class="alert"><%= t('messages.saved_successfully') %></div>
```

### 4. Test Anti-Patterns (CRITICAL)

#### ❌ **TEST SHORTCUTS (FORBIDDEN)**:
```ruby
# Skipping tests instead of fixing them
xit "should validate presence of title" do
  # Test implementation
end

# Empty tests that don't assert anything
it "should work correctly" do
  subject.perform
  # No expectations - MEANINGLESS
end

# Testing implementation instead of behavior
it "should call the service" do
  expect(SomeService).to receive(:perform).with(params)
  subject.call  # Only testing method calls, not outcomes
end

# Flaky test patterns
it "should complete processing" do
  subject.start_processing
  sleep(2)  # Timing-dependent test - FLAKY
  expect(subject.status).to eq('complete')
end
```

#### ✅ **PROPER TEST IMPLEMENTATION**:
```ruby
# Fix the test properly
it "validates presence of title" do
  listing = build(:listing, title: nil)
  expect(listing).not_to be_valid
  expect(listing.errors[:title]).to include("can't be blank")
end

# Test behavior and outcomes
it "creates a new listing with proper tenant scoping" do
  expect { subject.call }.to change { Current.tenant.listings.count }.by(1)

  created_listing = Current.tenant.listings.last
  expect(created_listing.title).to eq(expected_title)
  expect(created_listing.tenant).to eq(Current.tenant)
end

# Use proper waiting strategies
it "completes processing asynchronously" do
  subject.start_processing

  expect { subject.reload.status }.to eventually(eq('complete'))
    .within(5.seconds)
end
```

### 5. Architecture Anti-Patterns

#### ❌ **FAT CONTROLLERS/MODELS**:
```ruby
# Business logic in controller - WRONG
class ListingsController < ApplicationController
  def create
    @listing = Current.tenant.listings.new(listing_params)
    @listing.title = @listing.title.titleize
    @listing.slug = @listing.title.parameterize
    @listing.published_at = Time.current if should_publish?

    if @listing.save
      # Send notification email
      UserMailer.listing_created(@listing).deliver_now

      # Update analytics
      AnalyticsService.track('listing_created', @listing.id)

      # Clear cache
      Rails.cache.delete("tenant_#{Current.tenant.id}_listings")

      redirect_to @listing
    else
      render :new
    end
  end
end
```

#### ✅ **PROPER SERVICE ARCHITECTURE**:
```ruby
# Clean controller with service object
class ListingsController < ApplicationController
  def create
    result = Listings::CreateService.new(
      tenant: Current.tenant,
      params: listing_params,
      user: current_user
    ).call

    if result.success?
      redirect_to result.listing, notice: t('listings.created')
    else
      @listing = result.listing
      render :new
    end
  end
end

# Business logic in service
class Listings::CreateService
  def initialize(tenant:, params:, user:)
    @tenant = tenant
    @params = params
    @user = user
  end

  def call
    @listing = @tenant.listings.build(@params)

    enhance_listing

    if @listing.save
      post_creation_actions
      OpenStruct.new(success?: true, listing: @listing)
    else
      OpenStruct.new(success?: false, listing: @listing)
    end
  end

  private

  def enhance_listing
    @listing.title = @listing.title.titleize
    @listing.slug = @listing.title.parameterize
    @listing.published_at = Time.current if should_publish?
  end

  def post_creation_actions
    ListingCreatedJob.perform_later(@listing.id)
  end

  def should_publish?
    @user.can?(:publish, @listing)
  end
end
```

### 6. Performance Anti-Patterns

#### ❌ **N+1 QUERIES AND PERFORMANCE ISSUES**:
```ruby
# N+1 query pattern - INEFFICIENT
def index
  @listings = Current.tenant.listings.published

  @listings.each do |listing|
    listing.category.name  # N+1 query for each listing
    listing.user.name      # Another N+1 query
  end
end

# Blocking operations in request cycle - WRONG
def show
  @listing = Current.tenant.listings.find(params[:id])

  # AI processing in request - BLOCKS USER
  @ai_summary = OpenAI.summarize(@listing.content)
end
```

#### ✅ **PROPER PERFORMANCE PATTERNS**:
```ruby
# Eager loading to prevent N+1
def index
  @listings = Current.tenant.listings.published
                     .includes(:category, :user)
                     .limit(20)
end

# Async processing for heavy operations
def show
  @listing = Current.tenant.listings.find(params[:id])

  # Enqueue AI processing asynchronously
  AiSummaryJob.perform_later(@listing.id) unless @listing.ai_summary?
end
```

### 7. Security Anti-Patterns

#### ❌ **SECURITY SHORTCUTS**:
```ruby
# Exposing sensitive information
def user_data
  {
    id: user.id,
    email: user.email,
    password: user.encrypted_password,  # NEVER expose
    api_key: user.api_key              # NEVER expose
  }
end

# Weak parameter filtering
def listing_params
  params[:listing]  # No filtering - DANGEROUS
end

# Bypassing authorization
def admin_action
  # skip_authorization_check  # FORBIDDEN bypass
  perform_admin_task
end
```

#### ✅ **PROPER SECURITY IMPLEMENTATION**:
```ruby
# Safe data exposure
def user_data
  {
    id: user.id,
    name: user.name,
    avatar_url: user.avatar.url
  }
end

# Strong parameter filtering
def listing_params
  params.require(:listing).permit(:title, :description, :category_id)
end

# Proper authorization
def admin_action
  authorize! :admin, Current.tenant
  perform_admin_task
end
```

## Enforcement Mechanisms

### 1. Automated Detection
- **Anti-pattern detection script**: `./script/dev/anti-pattern-detection`
- **Pre-commit hooks**: Block commits with anti-patterns
- **CI/CD pipeline**: Validate in automated builds
- **Code review**: Human verification of complex cases

### 2. Quality Gates Integration
Anti-pattern detection is integrated into all quality gates:

```bash
# Runs as part of main quality script
./script/dev/quality  # Includes anti-pattern detection

# Can be run standalone
./script/dev/anti-pattern-detection

# Runs automatically on file changes via Guard
bundle exec guard  # Monitors for anti-patterns
```

### 3. Educational Approach
When anti-patterns are detected, the system provides:
- **Clear explanation** of why the pattern is problematic
- **Specific fix guidance** with proper implementation
- **Reference to best practices** and documentation
- **Examples** of correct implementation

## Best Practice Guidelines

### 1. Problem-Solving Approach
When facing a challenge:

1. **Understand the root cause** - Don't just fix symptoms
2. **Research proper patterns** - Check existing codebase and documentation
3. **Use established abstractions** - Services, decorators, jobs, etc.
4. **Test the solution properly** - Behavior, not implementation
5. **Consider long-term maintainability** - Not just immediate functionality

### 2. Implementation Priorities
1. **User experience first** - Solutions should improve UX
2. **Developer experience second** - Code should be maintainable
3. **Performance third** - Optimize after correctness
4. **Simplicity always** - Simple solutions over clever ones

### 3. Code Review Checklist
Before submitting code, verify:
- [ ] No quality tool bypasses or disabled checks
- [ ] Proper multi-tenant scoping (acts_as_tenant)
- [ ] All strings internationalized (no hardcoded text)
- [ ] Tests validate behavior, not implementation
- [ ] Business logic in appropriate layer (services, not controllers)
- [ ] Proper error handling without swallowing exceptions
- [ ] Security best practices followed
- [ ] Performance considerations addressed

## Examples of Proper Implementation

### Service Object Pattern
```ruby
# app/services/listings/publish_service.rb
class Listings::PublishService
  def initialize(listing:, user:)
    @listing = listing
    @user = user
  end

  def call
    return failure_result(t('errors.unauthorized')) unless can_publish?
    return failure_result(@listing.errors) unless @listing.valid?

    @listing.update!(published_at: Time.current, published_by: @user)
    notify_subscribers

    success_result(@listing)
  end

  private

  def can_publish?
    @user.can?(:publish, @listing)
  end

  def notify_subscribers
    ListingPublishedJob.perform_later(@listing.id)
  end

  def success_result(listing)
    OpenStruct.new(success?: true, listing: listing, errors: [])
  end

  def failure_result(errors)
    OpenStruct.new(success?: false, listing: @listing, errors: Array(errors))
  end
end
```

### Decorator Pattern
```ruby
# app/decorators/listing_decorator.rb
class ListingDecorator < Draper::Decorator
  delegate_all

  def formatted_publish_date
    return t('common.unpublished') unless published_at?

    I18n.l(published_at, format: :short)
  end

  def seo_title
    "#{title} | #{h.current_tenant.title}"
  end

  def social_share_description
    ai_summaries&.dig('short') || description&.truncate(160) ||
      t('listings.default_description', title: title)
  end
end
```

### Proper Testing
```ruby
# spec/services/listings/publish_service_spec.rb
RSpec.describe Listings::PublishService do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, tenant: tenant) }
  let(:listing) { create(:listing, tenant: tenant, published_at: nil) }

  before { ActsAsTenant.current_tenant = tenant }

  describe '#call' do
    context 'when user can publish' do
      before { allow(user).to receive(:can?).with(:publish, listing).and_return(true) }

      it 'publishes the listing successfully' do
        result = described_class.new(listing: listing, user: user).call

        expect(result).to be_success
        expect(result.listing.published_at).to be_present
        expect(result.listing.published_by).to eq(user)
      end

      it 'enqueues notification job' do
        expect { described_class.new(listing: listing, user: user).call }
          .to have_enqueued_job(ListingPublishedJob)
          .with(listing.id)
      end
    end

    context 'when user cannot publish' do
      before { allow(user).to receive(:can?).with(:publish, listing).and_return(false) }

      it 'returns failure with error message' do
        result = described_class.new(listing: listing, user: user).call

        expect(result).not_to be_success
        expect(result.errors).to include(I18n.t('errors.unauthorized'))
      end
    end
  end
end
```

## Summary

The anti-pattern prevention system ensures that:

1. **No shortcuts are taken** - All solutions follow proper patterns
2. **Quality is never compromised** - No bypassing of quality tools
3. **Architecture is respected** - Proper separation of concerns
4. **User experience is prioritized** - Solutions benefit end users
5. **Code remains maintainable** - Future developers can understand and extend
6. **Security is never weakened** - No security shortcuts or bypasses
7. **Performance is considered** - Efficient patterns are used
8. **Best practices are followed** - Industry standards are maintained

**Remember**: The goal is simple, clear, elegant, boring, best practice solutions that serve users well and maintain code quality over time.