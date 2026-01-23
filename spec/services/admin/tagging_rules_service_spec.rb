# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::TaggingRulesService, type: :service do
  let(:tenant) { create(:tenant) }
  # Use site from tenant factory
  let(:site) { tenant.sites.first }
  let(:taxonomy) { create(:taxonomy, site: site, tenant: tenant) }
  let(:service) { described_class.new(tenant) }

  before do
    Current.tenant = tenant
    Current.site = site
  end

  describe "#initialize" do
    it "sets the tenant" do
      expect(service.instance_variable_get(:@tenant)).to eq(tenant)
    end
  end

  describe "#all_rules" do
    let!(:rule1) { create(:tagging_rule, taxonomy: taxonomy, site: site, priority: 100) }
    let!(:rule2) { create(:tagging_rule, taxonomy: taxonomy, site: site, priority: 10) }
    let!(:other_tenant_rule) do
      # Create in a different tenant context
      ActsAsTenant.without_tenant do
        other_tenant = create(:tenant)
        other_site = other_tenant.sites.first
        other_taxonomy = create(:taxonomy, site: other_site, tenant: other_tenant)
        create(:tagging_rule, taxonomy: other_taxonomy, site: other_site, tenant: other_tenant)
      end
    end

    it "returns rules for the current tenant" do
      rules = service.all_rules
      expect(rules).to include(rule1, rule2)
      expect(rules).not_to include(other_tenant_rule)
    end

    it "includes taxonomy association" do
      rules = service.all_rules
      expect(rules.first.association(:taxonomy)).to be_loaded
    end

    it "orders by priority ascending" do
      rules = service.all_rules.to_a
      expect(rules.first).to eq(rule2) # priority 10
      expect(rules.last).to eq(rule1)  # priority 100
    end
  end

  describe "#rules_for_taxonomy" do
    let(:other_taxonomy) { create(:taxonomy, site: site, tenant: tenant) }
    let!(:rule_for_taxonomy) { create(:tagging_rule, taxonomy: taxonomy, site: site, priority: 50) }
    let!(:rule_for_other) { create(:tagging_rule, taxonomy: other_taxonomy, site: site, priority: 10) }

    it "returns only rules for the specified taxonomy" do
      rules = service.rules_for_taxonomy(taxonomy)
      expect(rules).to include(rule_for_taxonomy)
      expect(rules).not_to include(rule_for_other)
    end

    it "orders by priority" do
      rule2 = create(:tagging_rule, taxonomy: taxonomy, site: site, priority: 10)
      rules = service.rules_for_taxonomy(taxonomy).to_a
      expect(rules.first).to eq(rule2)
      expect(rules.last).to eq(rule_for_taxonomy)
    end
  end

  describe "#find_rule" do
    let!(:rule) { create(:tagging_rule, taxonomy: taxonomy, site: site) }

    it "finds the rule by id" do
      found = service.find_rule(rule.id)
      expect(found).to eq(rule)
    end

    it "includes tenant association" do
      found = service.find_rule(rule.id)
      expect(found.association(:tenant)).to be_loaded
    end

    it "includes taxonomy association" do
      found = service.find_rule(rule.id)
      expect(found.association(:taxonomy)).to be_loaded
    end

    it "raises error for non-existent rule" do
      expect {
        service.find_rule(99999)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "site scoping" do
    let(:other_site) { create(:site, tenant: tenant) }
    let(:other_taxonomy) { create(:taxonomy, site: other_site, tenant: tenant) }
    let!(:site_rule) { create(:tagging_rule, taxonomy: taxonomy, site: site) }
    let!(:other_site_rule) { create(:tagging_rule, taxonomy: other_taxonomy, site: other_site) }

    it "scopes to current site when set" do
      Current.site = site
      rules = service.all_rules
      expect(rules).to include(site_rule)
      expect(rules).not_to include(other_site_rule)
    end

    it "scopes to other site when changed" do
      Current.site = other_site
      rules = service.all_rules
      expect(rules).to include(other_site_rule)
      expect(rules).not_to include(site_rule)
    end
  end
end
