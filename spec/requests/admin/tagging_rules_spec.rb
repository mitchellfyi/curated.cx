# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::TaggingRules", type: :request do
  let!(:tenant1) { create(:tenant, :ai_news) }
  let!(:tenant2) { create(:tenant, :construction) }
  # Use the auto-created sites from tenant factory
  let!(:site1) { tenant1.sites.first }
  let!(:site2) { tenant2.sites.first }
  let(:admin_user) { create(:user, :admin) }
  let(:tenant1_owner) { create(:user) }
  let(:tenant2_owner) { create(:user) }

  let!(:taxonomy1) { create(:taxonomy, tenant: tenant1, site: site1, name: "Tech") }
  let!(:taxonomy2) do
    ActsAsTenant.without_tenant do
      create(:taxonomy, tenant: tenant2, site: site2, name: "Building")
    end
  end

  before do
    tenant1_owner.add_role(:owner, tenant1)
    tenant2_owner.add_role(:owner, tenant2)
  end

  describe "tenant scoping" do
    before do
      @tenant1_rule = create(:tagging_rule, taxonomy: taxonomy1, site: site1, pattern: "test1")
      @tenant2_rule = ActsAsTenant.without_tenant do
        create(:tagging_rule, taxonomy: taxonomy2, site: site2, pattern: "test2")
      end
    end

    context "when accessing as admin user" do
      before { sign_in admin_user }

      context "with tenant1 context" do
        before do
          host! tenant1.hostname
          setup_tenant_context(tenant1)
        end

        describe "GET /admin/tagging_rules" do
          it "only shows rules for the current tenant" do
            get admin_tagging_rules_path
            expect(response).to have_http_status(:success)
            expect(assigns(:tagging_rules)).to include(@tenant1_rule)
            expect(assigns(:tagging_rules)).not_to include(@tenant2_rule)
          end
        end

        describe "GET /admin/tagging_rules/:id" do
          it "can access rule from current tenant" do
            get admin_tagging_rule_path(@tenant1_rule)
            expect(response).to have_http_status(:success)
            expect(assigns(:tagging_rule)).to eq(@tenant1_rule)
          end

          it "cannot access rule from different tenant" do
            get admin_tagging_rule_path(@tenant2_rule)
            expect(response).to have_http_status(:not_found)
          end
        end

        describe "GET /admin/tagging_rules/new" do
          it "renders new form" do
            get new_admin_tagging_rule_path
            expect(response).to have_http_status(:success)
            expect(assigns(:tagging_rule)).to be_a_new(TaggingRule)
            expect(assigns(:taxonomies)).to include(taxonomy1)
          end
        end

        describe "POST /admin/tagging_rules" do
          it "creates rule for current tenant" do
            expect {
              post admin_tagging_rules_path, params: {
                tagging_rule: {
                  taxonomy_id: taxonomy1.id,
                  rule_type: "url_pattern",
                  pattern: "example\\.com/.*",
                  priority: 100,
                  enabled: true
                }
              }
            }.to change { site1.tagging_rules.count }.by(1)

            new_rule = TaggingRule.last
            expect(new_rule.taxonomy).to eq(taxonomy1)
            expect(new_rule.tenant).to eq(tenant1)
            expect(new_rule.site).to eq(site1)
            expect(new_rule.rule_type).to eq("url_pattern")
          end

          it "redirects to show on success" do
            post admin_tagging_rules_path, params: {
              tagging_rule: {
                taxonomy_id: taxonomy1.id,
                rule_type: "keyword",
                pattern: "test",
                priority: 100,
                enabled: true
              }
            }
            expect(response).to redirect_to(admin_tagging_rule_path(TaggingRule.last))
          end

          it "renders new with errors on invalid params" do
            post admin_tagging_rules_path, params: {
              tagging_rule: { pattern: "", priority: nil }
            }
            expect(response).to have_http_status(:unprocessable_content)
          end
        end

        describe "GET /admin/tagging_rules/:id/edit" do
          it "can edit rule from current tenant" do
            get edit_admin_tagging_rule_path(@tenant1_rule)
            expect(response).to have_http_status(:success)
            expect(assigns(:tagging_rule)).to eq(@tenant1_rule)
          end

          it "cannot edit rule from different tenant" do
            get edit_admin_tagging_rule_path(@tenant2_rule)
            expect(response).to have_http_status(:not_found)
          end
        end

        describe "PATCH /admin/tagging_rules/:id" do
          it "updates rule" do
            patch admin_tagging_rule_path(@tenant1_rule), params: {
              tagging_rule: { pattern: "updated-pattern" }
            }
            expect(@tenant1_rule.reload.pattern).to eq("updated-pattern")
            expect(response).to redirect_to(admin_tagging_rule_path(@tenant1_rule))
          end

          it "renders edit with errors on invalid params" do
            patch admin_tagging_rule_path(@tenant1_rule), params: {
              tagging_rule: { pattern: "" }
            }
            expect(response).to have_http_status(:unprocessable_content)
          end
        end

        describe "DELETE /admin/tagging_rules/:id" do
          it "destroys rule" do
            expect {
              delete admin_tagging_rule_path(@tenant1_rule)
            }.to change { TaggingRule.count }.by(-1)
            expect(response).to redirect_to(admin_tagging_rules_path)
          end

          it "cannot destroy rule from different tenant" do
            expect {
              delete admin_tagging_rule_path(@tenant2_rule)
            }.not_to change { TaggingRule.count }
            expect(response).to have_http_status(:not_found)
          end
        end

        describe "POST /admin/tagging_rules/:id/test" do
          let!(:entry) do
            source = create(:source, site: site1, tenant: tenant1)
            create(:entry, :feed, site: site1, source: source,
              url_canonical: "https://example.com/news/article",
              title: "Test Article")
          end

          it "tests rule against content items" do
            get test_admin_tagging_rule_path(@tenant1_rule)
            expect(response).to have_http_status(:success)
            expect(assigns(:content_items)).to include(entry)
            expect(assigns(:results)).to be_present
          end

          it "includes match results for each content item" do
            get test_admin_tagging_rule_path(@tenant1_rule)
            result = assigns(:results).first
            expect(result).to have_key(:content_item)
            expect(result).to have_key(:match_result)
          end
        end
      end

      context "with tenant2 context" do
        before do
          host! tenant2.hostname
          setup_tenant_context(tenant2)
        end

        describe "GET /admin/tagging_rules" do
          it "only shows rules for the current tenant" do
            get admin_tagging_rules_path
            expect(response).to have_http_status(:success)
            expect(assigns(:tagging_rules)).to include(@tenant2_rule)
            expect(assigns(:tagging_rules)).not_to include(@tenant1_rule)
          end
        end
      end
    end

    context "when accessing as tenant owner" do
      before { sign_in tenant1_owner }

      context "with tenant1 context" do
        before do
          host! tenant1.hostname
          setup_tenant_context(tenant1)
        end

        describe "GET /admin/tagging_rules" do
          it "only shows rules for the current tenant" do
            get admin_tagging_rules_path
            expect(response).to have_http_status(:success)
            expect(assigns(:tagging_rules)).to include(@tenant1_rule)
            expect(assigns(:tagging_rules)).not_to include(@tenant2_rule)
          end
        end

        describe "POST /admin/tagging_rules" do
          it "creates rule for current tenant" do
            expect {
              post admin_tagging_rules_path, params: {
                tagging_rule: {
                  taxonomy_id: taxonomy1.id,
                  rule_type: "keyword",
                  pattern: "owner-keyword",
                  priority: 50,
                  enabled: true
                }
              }
            }.to change { site1.tagging_rules.count }.by(1)

            new_rule = TaggingRule.last
            expect(new_rule.tenant).to eq(tenant1)
          end
        end
      end
    end

    context "when accessing without proper permissions" do
      let(:regular_user) { create(:user) }
      before { sign_in regular_user }

      context "with tenant1 context" do
        before do
          host! tenant1.hostname
          setup_tenant_context(tenant1)
        end

        describe "GET /admin/tagging_rules" do
          it "redirects with access denied" do
            get admin_tagging_rules_path
            expect(response).to redirect_to(root_path)
            expect(flash[:alert]).to eq("Access denied. Admin privileges required.")
          end
        end
      end
    end
  end

  describe "rule type features" do
    let(:admin_user) { create(:user, :admin) }

    before do
      sign_in admin_user
      host! tenant1.hostname
      setup_tenant_context(tenant1)
    end

    describe "creating different rule types" do
      it "creates url_pattern rule" do
        post admin_tagging_rules_path, params: {
          tagging_rule: {
            taxonomy_id: taxonomy1.id,
            rule_type: "url_pattern",
            pattern: "example\\.com/news/.*",
            priority: 100,
            enabled: true
          }
        }

        rule = TaggingRule.last
        expect(rule.url_pattern?).to be true
      end

      it "creates source rule" do
        post admin_tagging_rules_path, params: {
          tagging_rule: {
            taxonomy_id: taxonomy1.id,
            rule_type: "source",
            pattern: "123",
            priority: 100,
            enabled: true
          }
        }

        rule = TaggingRule.last
        expect(rule.source?).to be true
      end

      it "creates keyword rule" do
        post admin_tagging_rules_path, params: {
          tagging_rule: {
            taxonomy_id: taxonomy1.id,
            rule_type: "keyword",
            pattern: "technology, ai, machine learning",
            priority: 100,
            enabled: true
          }
        }

        rule = TaggingRule.last
        expect(rule.keyword?).to be true
      end

      it "creates domain rule" do
        post admin_tagging_rules_path, params: {
          tagging_rule: {
            taxonomy_id: taxonomy1.id,
            rule_type: "domain",
            pattern: "*.techcrunch.com",
            priority: 100,
            enabled: true
          }
        }

        rule = TaggingRule.last
        expect(rule.domain?).to be true
      end
    end
  end
end
