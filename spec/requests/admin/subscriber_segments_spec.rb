# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::SubscriberSegments", type: :request do
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
    describe "GET /admin/subscriber_segments" do
      context "when not signed in" do
        it "redirects to sign in" do
          get admin_subscriber_segments_path

          expect(response).to redirect_to(new_user_session_path)
        end
      end

      context "when signed in as regular user" do
        before { sign_in regular_user }

        it "denies access" do
          get admin_subscriber_segments_path

          expect(response).to redirect_to(root_path)
        end
      end

      context "when signed in as admin" do
        before { sign_in admin_user }

        it "allows access" do
          get admin_subscriber_segments_path

          expect(response).to have_http_status(:success)
        end
      end

      context "when signed in as tenant owner" do
        before { sign_in tenant_owner }

        it "allows access" do
          get admin_subscriber_segments_path

          expect(response).to have_http_status(:success)
        end
      end
    end
  end

  describe "GET /admin/subscriber_segments" do
    before { sign_in admin_user }

    context "with system segments from site creation" do
      it "shows system segments" do
        get admin_subscriber_segments_path

        segments = assigns(:subscriber_segments)
        expect(segments.pluck(:name)).to include("All Subscribers", "Active (30 days)", "New (7 days)", "Power Users")
      end
    end

    context "with custom segments" do
      let!(:custom_segment) { create(:subscriber_segment, site: site, name: "Custom Segment", system_segment: false) }

      it "shows custom segments along with system segments" do
        get admin_subscriber_segments_path

        segments = assigns(:subscriber_segments)
        expect(segments).to include(custom_segment)
      end

      it "orders system segments first" do
        get admin_subscriber_segments_path

        segments = assigns(:subscriber_segments)
        system_segments = segments.select(&:system_segment?)
        custom_segments = segments.reject(&:system_segment?)
        expect(segments.to_a).to eq(system_segments + custom_segments)
      end
    end

    context "tenant isolation" do
      let!(:other_tenant) { create(:tenant, :enabled) }
      let(:other_site) { create(:site, tenant: other_tenant) }
      let!(:other_segment) do
        ActsAsTenant.without_tenant do
          create(:subscriber_segment, site: other_site, tenant: other_tenant, name: "Other Tenant Segment")
        end
      end
      let!(:site_segment) { create(:subscriber_segment, site: site, name: "My Segment") }

      it "only shows segments for current site" do
        get admin_subscriber_segments_path

        expect(assigns(:subscriber_segments)).to include(site_segment)
        expect(assigns(:subscriber_segments)).not_to include(other_segment)
      end
    end
  end

  describe "GET /admin/subscriber_segments/:id" do
    let!(:segment) { create(:subscriber_segment, site: site, name: "Test Segment", rules: {}) }
    let!(:user) { create(:user) }
    let!(:subscription) { create(:digest_subscription, user: user, site: site) }

    before { sign_in admin_user }

    it "shows segment details" do
      get admin_subscriber_segment_path(segment)

      expect(response).to have_http_status(:success)
      expect(assigns(:subscriber_segment)).to eq(segment)
    end

    it "shows subscriber count" do
      get admin_subscriber_segment_path(segment)

      expect(assigns(:subscribers_count)).to eq(1)
    end

    it "shows sample subscribers" do
      get admin_subscriber_segment_path(segment)

      expect(assigns(:sample_subscribers)).to include(subscription)
    end
  end

  describe "GET /admin/subscriber_segments/new" do
    before { sign_in admin_user }

    it "renders new form" do
      get new_admin_subscriber_segment_path

      expect(response).to have_http_status(:success)
      expect(assigns(:subscriber_segment)).to be_a_new(SubscriberSegment)
    end

    it "loads available tags" do
      tag = create(:subscriber_tag, site: site, name: "VIP")

      get new_admin_subscriber_segment_path

      expect(assigns(:subscriber_tags)).to include(tag)
    end
  end

  describe "POST /admin/subscriber_segments" do
    before { sign_in admin_user }

    context "with valid params" do
      it "creates a new custom segment" do
        expect {
          post admin_subscriber_segments_path, params: {
            subscriber_segment: {
              name: "New Segment",
              description: "Test description",
              enabled: true,
              rules: { active: "true" }
            }
          }
        }.to change { SubscriberSegment.custom.count }.by(1)

        new_segment = SubscriberSegment.last
        expect(new_segment.name).to eq("New Segment")
        expect(new_segment.site).to eq(site)
        expect(new_segment.system_segment?).to be false
      end

      it "redirects to show" do
        post admin_subscriber_segments_path, params: {
          subscriber_segment: { name: "New Segment", enabled: true }
        }

        expect(response).to redirect_to(admin_subscriber_segment_path(SubscriberSegment.last))
      end

      it "parses rules correctly" do
        post admin_subscriber_segments_path, params: {
          subscriber_segment: {
            name: "Engaged Weekly",
            enabled: true,
            rules: {
              frequency: "weekly",
              active: "true",
              subscription_age: { max_days: "30" }
            }
          }
        }

        segment = SubscriberSegment.last
        expect(segment.rules["frequency"]).to eq("weekly")
        expect(segment.rules["active"]).to be true
        expect(segment.rules["subscription_age"]["max_days"]).to eq(30)
      end
    end

    context "with invalid params" do
      it "renders new with errors" do
        post admin_subscriber_segments_path, params: {
          subscriber_segment: { name: "" }
        }

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "GET /admin/subscriber_segments/:id/edit" do
    before { sign_in admin_user }

    context "with custom segment" do
      let!(:segment) { create(:subscriber_segment, site: site, name: "Custom", system_segment: false) }

      it "renders edit form" do
        get edit_admin_subscriber_segment_path(segment)

        expect(response).to have_http_status(:success)
        expect(assigns(:subscriber_segment)).to eq(segment)
      end
    end

    context "with system segment" do
      let!(:system_segment) { site.subscriber_segments.find_by(system_segment: true) }

      it "redirects with error" do
        get edit_admin_subscriber_segment_path(system_segment)

        expect(response).to redirect_to(admin_subscriber_segments_path)
        expect(flash[:alert]).to eq(I18n.t("admin.subscriber_segments.system_protected"))
      end
    end
  end

  describe "PATCH /admin/subscriber_segments/:id" do
    before { sign_in admin_user }

    context "with custom segment" do
      let!(:segment) { create(:subscriber_segment, site: site, name: "Old Name", system_segment: false) }

      context "with valid params" do
        it "updates the segment" do
          patch admin_subscriber_segment_path(segment), params: {
            subscriber_segment: { name: "New Name" }
          }

          expect(segment.reload.name).to eq("New Name")
          expect(response).to redirect_to(admin_subscriber_segment_path(segment))
        end
      end

      context "with invalid params" do
        it "renders edit with errors" do
          patch admin_subscriber_segment_path(segment), params: {
            subscriber_segment: { name: "" }
          }

          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end

    context "with system segment" do
      let!(:system_segment) { site.subscriber_segments.find_by(system_segment: true) }

      it "redirects with error" do
        patch admin_subscriber_segment_path(system_segment), params: {
          subscriber_segment: { name: "Hacked" }
        }

        expect(response).to redirect_to(admin_subscriber_segments_path)
        expect(system_segment.reload.name).not_to eq("Hacked")
      end
    end
  end

  describe "DELETE /admin/subscriber_segments/:id" do
    before { sign_in admin_user }

    context "with custom segment" do
      let!(:segment) { create(:subscriber_segment, site: site, name: "To Delete", system_segment: false) }

      it "deletes the segment" do
        expect {
          delete admin_subscriber_segment_path(segment)
        }.to change { SubscriberSegment.custom.count }.by(-1)

        expect(response).to redirect_to(admin_subscriber_segments_path)
      end
    end

    context "with system segment" do
      let!(:system_segment) { site.subscriber_segments.find_by(system_segment: true) }
      let(:initial_count) { SubscriberSegment.system.count }

      it "does not delete system segment" do
        before_count = SubscriberSegment.system.count

        delete admin_subscriber_segment_path(system_segment)

        expect(SubscriberSegment.system.count).to eq(before_count)
        expect(response).to redirect_to(admin_subscriber_segments_path)
      end
    end
  end

  describe "POST /admin/subscriber_segments/:id/preview" do
    let!(:segment) { create(:subscriber_segment, site: site, name: "Preview Test") }
    let!(:user1) { create(:user) }
    let!(:user2) { create(:user) }
    let!(:active_sub) { create(:digest_subscription, user: user1, site: site, active: true) }
    let!(:inactive_sub) { create(:digest_subscription, user: user2, site: site, active: false) }

    before { sign_in admin_user }

    it "returns count of matching subscribers" do
      post preview_admin_subscriber_segment_path(segment), params: {
        rules: { active: "true" }
      }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["count"]).to eq(1)
    end

    it "works with multiple rules" do
      post preview_admin_subscriber_segment_path(segment), params: {
        rules: { active: "true", frequency: "weekly" }
      }

      expect(response).to have_http_status(:success)
    end
  end
end
