# frozen_string_literal: true

require "rails_helper"

RSpec.describe SiteScoped, type: :model do
  # Test using Category model which includes both SiteScoped and TenantScoped
  let(:tenant1) { create(:tenant) }
  let(:tenant2) { create(:tenant) }
  let(:site1) { create(:site, tenant: tenant1) }
  let(:site2) { create(:site, tenant: tenant1) }
  let(:site3) { create(:site, tenant: tenant2) }

  # Create records outside of tenant context to avoid acts_as_tenant interference
  let!(:record1) do
    ActsAsTenant.without_tenant do
      create(:category, tenant: tenant1, site: site1, key: "test1", name: "Test 1")
    end
  end

  let!(:record2) do
    ActsAsTenant.without_tenant do
      create(:category, tenant: tenant1, site: site2, key: "test2", name: "Test 2")
    end
  end

  let!(:record3) do
    ActsAsTenant.without_tenant do
      create(:category, tenant: tenant2, site: site3, key: "test3", name: "Test 3")
    end
  end

  after do
    Current.reset
    ActsAsTenant.current_tenant = nil
  end

  describe "site scoping" do
    it "validates site presence" do
      ActsAsTenant.without_tenant do
        record = Category.new(key: "new_cat", name: "New Category", tenant: tenant1)
        expect(record).not_to be_valid
        expect(record.errors[:site]).to include("must exist")
      end
    end
  end

  describe ".without_site_scope" do
    it "returns all records regardless of site" do
      records = Category.without_site_scope
      expect(records).to include(record1, record2, record3)
    end
  end

  describe ".for_site" do
    it "returns records for specific site" do
      records = Category.for_site(site1)
      expect(records).to include(record1)
      expect(records).not_to include(record2, record3)
    end

    it "returns records for different site" do
      records = Category.for_site(site2)
      expect(records).to include(record2)
      expect(records).not_to include(record1, record3)
    end
  end

  describe ".require_site!" do
    it "raises error when Current.site is nil" do
      Current.reset
      expect {
        Category.require_site!
      }.to raise_error("Current.site must be set to perform this operation")
    end

    it "does not raise error when Current.site is set" do
      Current.site = site1
      expect {
        Category.require_site!
      }.not_to raise_error
    end
  end

  describe "#ensure_site_consistency!" do
    it "raises error when record belongs to different site" do
      Current.site = site2
      expect {
        record1.ensure_site_consistency!
      }.to raise_error("Record belongs to different site than Current.site")
    end

    it "does not raise error when record belongs to current site" do
      Current.site = site1
      expect {
        record1.ensure_site_consistency!
      }.not_to raise_error
    end

    it "does not raise error when Current.site is nil" do
      Current.reset
      expect {
        record1.ensure_site_consistency!
      }.not_to raise_error
    end
  end

  describe "tenant consistency" do
    describe "#set_tenant_from_site" do
      context "when model includes TenantScoped" do
        it "sets tenant from site on create when tenant is nil" do
          ActsAsTenant.without_tenant do
            record = Category.new(site: site1, key: "new_cat", name: "New Category")
            record.valid?
            expect(record.tenant).to eq(tenant1)
          end
        end

        it "does not override existing tenant" do
          ActsAsTenant.without_tenant do
            record = Category.new(site: site1, tenant: tenant2, key: "new_cat", name: "New Category")
            record.valid?
            expect(record.tenant).to eq(tenant2)
          end
        end

        it "only runs on create" do
          ActsAsTenant.without_tenant do
            # Create with matching tenant/site
            record = create(:category, site: site1, tenant: tenant1, key: "existing", name: "Existing")
            # Change site to site with different tenant
            record.site = site3
            record.valid?
            # Tenant should NOT be changed (callback only runs on create)
            expect(record.tenant).to eq(tenant1)
          end
        end
      end

      context "when model does not include TenantScoped" do
        # ContentItem includes SiteScoped but not TenantScoped
        it "does not attempt to set tenant" do
          ActsAsTenant.without_tenant do
            source = create(:source, site: site1, tenant: tenant1)
            # ContentItem does not have a tenant attribute
            content_item = ContentItem.new(
              site: site1,
              source: source,
              url_canonical: "https://example.com/article",
              title: "Test Article"
            )
            expect { content_item.valid? }.not_to raise_error
          end
        end
      end
    end

    describe "#ensure_site_tenant_consistency" do
      context "when model includes TenantScoped" do
        it "allows record when tenant matches site tenant" do
          ActsAsTenant.without_tenant do
            record = Category.new(site: site1, tenant: tenant1, key: "valid", name: "Valid")
            expect(record).to be_valid
          end
        end

        it "rejects record when tenant does not match site tenant" do
          ActsAsTenant.without_tenant do
            record = Category.new(site: site1, tenant: tenant2, key: "invalid", name: "Invalid")
            expect(record).not_to be_valid
            expect(record.errors[:site]).to include("must belong to the same tenant")
          end
        end

        it "allows record when tenant is nil (will be set by callback)" do
          ActsAsTenant.without_tenant do
            record = Category.new(site: site1, tenant: nil, key: "auto", name: "Auto")
            expect(record).to be_valid
          end
        end

        it "allows record when site is nil (will fail site validation instead)" do
          ActsAsTenant.without_tenant do
            record = Category.new(site: nil, tenant: tenant1, key: "no_site", name: "No Site")
            # Should fail on site presence, not tenant consistency
            expect(record).not_to be_valid
            expect(record.errors[:site]).to include("must exist")
          end
        end
      end

      context "when model does not include TenantScoped" do
        # ContentItem includes SiteScoped but not TenantScoped
        it "skips tenant consistency validation" do
          ActsAsTenant.without_tenant do
            source = create(:source, site: site1, tenant: tenant1)
            content_item = ContentItem.new(
              site: site1,
              source: source,
              url_canonical: "https://example.com/article",
              title: "Test Article"
            )
            content_item.valid?
            # Should not have site tenant consistency error (no tenant attribute)
            expect(content_item.errors[:site]).not_to include("must belong to the same tenant")
          end
        end
      end
    end
  end
end
