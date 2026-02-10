# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Flags", type: :request do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:source) { create(:source, site: site) }
  let(:admin) { create(:user, admin: true) }
  let(:owner) { create(:user).tap { |u| u.add_role(:owner, tenant) } }
  let(:tenant_admin) { create(:user).tap { |u| u.add_role(:admin, tenant) } }
  let(:user) { create(:user) }
  let(:flagger) { create(:user) }
  let(:entry) { create(:entry, :feed, :published, site: site, source: source) }

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
  end

  describe "GET /admin/flags" do
    context "when user is global admin" do
      before { sign_in admin }

      let!(:pending_flags) { create_list(:flag, 3, flaggable: entry, site: site) }
      let!(:resolved_flag) { create(:flag, :reviewed, flaggable: entry, site: site) }

      it "returns http success" do
        get admin_flags_path

        expect(response).to have_http_status(:success)
      end

      it "assigns pending flags" do
        get admin_flags_path

        expect(assigns(:flags).to_a).to match_array(pending_flags)
      end

      it "assigns resolved flags" do
        get admin_flags_path

        expect(assigns(:resolved_flags)).to include(resolved_flag)
      end

      it "does not include resolved flags in pending" do
        get admin_flags_path

        expect(assigns(:flags)).not_to include(resolved_flag)
      end
    end

    context "when user is tenant owner" do
      before { sign_in owner }

      it "returns http success" do
        get admin_flags_path

        expect(response).to have_http_status(:success)
      end
    end

    context "when user is tenant admin" do
      before { sign_in tenant_admin }

      it "returns http success" do
        get admin_flags_path

        expect(response).to have_http_status(:success)
      end
    end

    context "when user is regular user" do
      before { sign_in user }

      it "redirects to root" do
        get admin_flags_path

        expect(response).to redirect_to(root_path)
      end
    end

    context "when user is not authenticated" do
      it "redirects to sign in" do
        get admin_flags_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /admin/flags/:id" do
    let!(:flag) { create(:flag, flaggable: entry, user: flagger, site: site) }

    context "when user is admin" do
      before { sign_in admin }

      it "returns http success" do
        get admin_flag_path(flag)

        expect(response).to have_http_status(:success)
      end

      it "assigns the flag" do
        get admin_flag_path(flag)

        expect(assigns(:flag)).to eq(flag)
      end
    end

    context "when user is regular user" do
      before { sign_in user }

      it "redirects to root" do
        get admin_flag_path(flag)

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "POST /admin/flags/:id/resolve" do
    let!(:flag) { create(:flag, flaggable: entry, user: flagger, site: site) }

    context "when user is admin" do
      before { sign_in admin }

      it "marks the flag as action_taken" do
        post resolve_admin_flag_path(flag)

        flag.reload
        expect(flag.status).to eq("action_taken")
      end

      it "sets the reviewer" do
        post resolve_admin_flag_path(flag)

        flag.reload
        expect(flag.reviewed_by).to eq(admin)
      end

      it "sets the reviewed_at timestamp" do
        freeze_time do
          post resolve_admin_flag_path(flag)

          flag.reload
          expect(flag.reviewed_at).to eq(Time.current)
        end
      end

      it "redirects to flags index" do
        post resolve_admin_flag_path(flag)

        expect(response).to redirect_to(admin_flags_path)
      end

      it "sets a success notice" do
        post resolve_admin_flag_path(flag)

        expect(flash[:notice]).to eq(I18n.t("admin.flags.resolved"))
      end

      context "with turbo stream format" do
        it "responds with turbo stream" do
          post resolve_admin_flag_path(flag), as: :turbo_stream

          expect(response.content_type).to include("text/vnd.turbo-stream.html")
        end
      end
    end

    context "when user is regular user" do
      before { sign_in user }

      it "redirects to root" do
        post resolve_admin_flag_path(flag)

        expect(response).to redirect_to(root_path)
      end

      it "does not resolve the flag" do
        post resolve_admin_flag_path(flag)

        flag.reload
        expect(flag.pending?).to be true
      end
    end
  end

  describe "POST /admin/flags/:id/dismiss" do
    let!(:flag) { create(:flag, flaggable: entry, user: flagger, site: site) }

    context "when user is admin" do
      before { sign_in admin }

      it "marks the flag as dismissed" do
        post dismiss_admin_flag_path(flag)

        flag.reload
        expect(flag.status).to eq("dismissed")
      end

      it "sets the reviewer" do
        post dismiss_admin_flag_path(flag)

        flag.reload
        expect(flag.reviewed_by).to eq(admin)
      end

      it "sets the reviewed_at timestamp" do
        freeze_time do
          post dismiss_admin_flag_path(flag)

          flag.reload
          expect(flag.reviewed_at).to eq(Time.current)
        end
      end

      it "redirects to flags index" do
        post dismiss_admin_flag_path(flag)

        expect(response).to redirect_to(admin_flags_path)
      end

      it "sets a success notice" do
        post dismiss_admin_flag_path(flag)

        expect(flash[:notice]).to eq(I18n.t("admin.flags.dismissed"))
      end

      context "with turbo stream format" do
        it "responds with turbo stream" do
          post dismiss_admin_flag_path(flag), as: :turbo_stream

          expect(response.content_type).to include("text/vnd.turbo-stream.html")
        end
      end
    end

    context "when user is regular user" do
      before { sign_in user }

      it "redirects to root" do
        post dismiss_admin_flag_path(flag)

        expect(response).to redirect_to(root_path)
      end

      it "does not dismiss the flag" do
        post dismiss_admin_flag_path(flag)

        flag.reload
        expect(flag.pending?).to be true
      end
    end
  end

  describe "site isolation" do
    let!(:flag) { create(:flag, flaggable: entry, user: flagger, site: site) }

    before { sign_in admin }

    context "with flag from another site" do
      let(:other_tenant) { create(:tenant, :enabled) }
      let(:other_flag) do
        ActsAsTenant.with_tenant(other_tenant) do
          other_site = other_tenant.sites.first || create(:site, tenant: other_tenant)
          other_source = create(:source, site: other_site)
          other_content = create(:entry, :feed, :published, site: other_site, source: other_source)
          create(:flag, flaggable: other_content, site: other_site)
        end
      end

      it "only shows flags from current site" do
        other_flag # create it

        get admin_flags_path

        expect(assigns(:flags)).to include(flag)
        expect(assigns(:flags)).not_to include(other_flag)
      end

      it "cannot access flags from other sites" do
        get admin_flag_path(other_flag)

        expect(response).to have_http_status(:not_found)
      end

      it "cannot resolve flags from other sites" do
        post resolve_admin_flag_path(other_flag)

        expect(response).to have_http_status(:not_found)
      end

      it "cannot dismiss flags from other sites" do
        post dismiss_admin_flag_path(other_flag)

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
