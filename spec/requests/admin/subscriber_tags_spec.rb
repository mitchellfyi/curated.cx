# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::SubscriberTags", type: :request do
  let!(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:admin_user) { create(:user, :admin) }
  let(:regular_user) { create(:user) }
  let(:tenant_owner) { create(:user).tap { |u| u.add_role(:owner, tenant) } }

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
  end

  describe "authentication and authorization" do
    describe "GET /admin/subscriber_tags" do
      context "when not signed in" do
        it "redirects to sign in" do
          get admin_subscriber_tags_path

          expect(response).to redirect_to(new_user_session_path)
        end
      end

      context "when signed in as regular user" do
        before { sign_in regular_user }

        it "denies access" do
          get admin_subscriber_tags_path

          expect(response).to redirect_to(root_path)
        end
      end

      context "when signed in as admin" do
        before { sign_in admin_user }

        it "allows access" do
          get admin_subscriber_tags_path

          expect(response).to have_http_status(:success)
        end
      end

      context "when signed in as tenant owner" do
        before { sign_in tenant_owner }

        it "allows access" do
          get admin_subscriber_tags_path

          expect(response).to have_http_status(:success)
        end
      end
    end
  end

  describe "GET /admin/subscriber_tags" do
    before { sign_in admin_user }

    context "with no tags" do
      it "shows empty list" do
        get admin_subscriber_tags_path

        expect(assigns(:subscriber_tags)).to be_empty
      end
    end

    context "with tags" do
      let!(:tag_z) { create(:subscriber_tag, site: site, name: "Zebra") }
      let!(:tag_a) { create(:subscriber_tag, site: site, name: "Alpha") }

      it "shows tags ordered alphabetically" do
        get admin_subscriber_tags_path

        tags = assigns(:subscriber_tags)
        expect(tags.first).to eq(tag_a)
        expect(tags.last).to eq(tag_z)
      end
    end

    context "tenant isolation" do
      let!(:other_tenant) { create(:tenant, :enabled) }
      let(:other_site) { create(:site, tenant: other_tenant) }
      let!(:other_tag) do
        ActsAsTenant.without_tenant do
          create(:subscriber_tag, site: other_site, tenant: other_tenant, name: "Other")
        end
      end
      let!(:site_tag) { create(:subscriber_tag, site: site, name: "Mine") }

      it "only shows tags for current site" do
        get admin_subscriber_tags_path

        expect(assigns(:subscriber_tags)).to include(site_tag)
        expect(assigns(:subscriber_tags)).not_to include(other_tag)
      end
    end
  end

  describe "GET /admin/subscriber_tags/new" do
    before { sign_in admin_user }

    it "renders new form" do
      get new_admin_subscriber_tag_path

      expect(response).to have_http_status(:success)
      expect(assigns(:subscriber_tag)).to be_a_new(SubscriberTag)
    end
  end

  describe "POST /admin/subscriber_tags" do
    before { sign_in admin_user }

    context "with valid params" do
      it "creates a new tag" do
        expect {
          post admin_subscriber_tags_path, params: {
            subscriber_tag: { name: "VIP Members" }
          }
        }.to change { SubscriberTag.count }.by(1)

        new_tag = SubscriberTag.last
        expect(new_tag.name).to eq("VIP Members")
        expect(new_tag.slug).to eq("vip-members")
        expect(new_tag.site).to eq(site)
      end

      it "redirects to index" do
        post admin_subscriber_tags_path, params: {
          subscriber_tag: { name: "VIP Members" }
        }

        expect(response).to redirect_to(admin_subscriber_tags_path)
      end
    end

    context "with invalid params" do
      it "renders new with errors" do
        post admin_subscriber_tags_path, params: {
          subscriber_tag: { name: "" }
        }

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "GET /admin/subscriber_tags/:id/edit" do
    let!(:tag) { create(:subscriber_tag, site: site, name: "Test Tag") }

    before { sign_in admin_user }

    it "renders edit form" do
      get edit_admin_subscriber_tag_path(tag.slug)

      expect(response).to have_http_status(:success)
      expect(assigns(:subscriber_tag)).to eq(tag)
    end
  end

  describe "PATCH /admin/subscriber_tags/:id" do
    let!(:tag) { create(:subscriber_tag, site: site, name: "Old Name") }

    before { sign_in admin_user }

    context "with valid params" do
      it "updates the tag" do
        patch admin_subscriber_tag_path(tag.slug), params: {
          subscriber_tag: { name: "New Name" }
        }

        expect(tag.reload.name).to eq("New Name")
        expect(response).to redirect_to(admin_subscriber_tags_path)
      end
    end

    context "with invalid params" do
      it "renders edit with errors" do
        patch admin_subscriber_tag_path(tag.slug), params: {
          subscriber_tag: { name: "" }
        }

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "DELETE /admin/subscriber_tags/:id" do
    let!(:tag) { create(:subscriber_tag, site: site, name: "To Delete") }

    before { sign_in admin_user }

    it "deletes the tag" do
      expect {
        delete admin_subscriber_tag_path(tag.slug)
      }.to change { SubscriberTag.count }.by(-1)

      expect(response).to redirect_to(admin_subscriber_tags_path)
    end
  end
end
