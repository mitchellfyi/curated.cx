require 'rails_helper'

RSpec.describe "Admin::Listings", type: :request do
  let!(:tenant1) { create(:tenant, :ai_news) }
  let!(:tenant2) { create(:tenant, :construction) }
  # Use the auto-created sites from tenant factory
  let!(:site1) { tenant1.sites.first }
  let!(:site2) { tenant2.sites.first }
  let(:admin_user) { create(:user, :admin) }
  let(:tenant1_owner) { create(:user) }
  let(:tenant2_owner) { create(:user) }

  before do
    # Set up roles
    tenant1_owner.add_role(:owner, tenant1)
    tenant2_owner.add_role(:owner, tenant2)
  end

      describe "tenant scoping" do
        before do
          @tenant1_category = create(:category, :news, tenant: tenant1, site: site1)
          @tenant2_category = create(:category, :news, tenant: tenant2, site: site2)
          @tenant1_listing = create(:entry, :directory, tenant: tenant1, site: site1, category: @tenant1_category)
          @tenant2_listing = create(:entry, :directory, tenant: tenant2, site: site2, category: @tenant2_category)
        end

    context "when accessing as admin user" do
      before { sign_in admin_user }

      context "with tenant1 context" do
        before do
          host! tenant1.hostname
          setup_tenant_context(tenant1)
        end

        describe "GET /admin/entries" do
          it "only shows entries for the current tenant" do
            get admin_entries_path
            expect(response).to have_http_status(:success)
            expect(assigns(:entries)).to include(@tenant1_listing)
            expect(assigns(:entries)).not_to include(@tenant2_listing)
          end

          it "only shows categories for the current tenant" do
            get admin_entries_path
            expect(response).to have_http_status(:success)
            expect(assigns(:categories)).to include(@tenant1_category)
            expect(assigns(:categories)).not_to include(@tenant2_category)
          end
        end

        describe "GET /admin/entries/:id" do
          it "can access entry from current tenant" do
            get admin_entry_path(@tenant1_listing)
            expect(response).to have_http_status(:success)
            expect(assigns(:entry)).to eq(@tenant1_listing)
          end

          it "cannot access entry from different tenant" do
            get admin_entry_path(@tenant2_listing)
            expect(response).to have_http_status(:not_found)
          end
        end

        describe "GET /admin/entries/:id/edit" do
          it "can edit entry from current tenant" do
            get edit_admin_entry_path(@tenant1_listing)
            expect(response).to have_http_status(:success)
            expect(assigns(:entry)).to eq(@tenant1_listing)
            expect(assigns(:categories)).to include(@tenant1_category)
            expect(assigns(:categories)).not_to include(@tenant2_category)
          end

          it "cannot edit entry from different tenant" do
            get edit_admin_entry_path(@tenant2_listing)
            expect(response).to have_http_status(:not_found)
          end
        end

        describe "GET /admin/entries/new" do
          it "only shows categories for the current tenant" do
            get new_admin_entry_path
            expect(response).to have_http_status(:success)
            expect(assigns(:categories)).to include(@tenant1_category)
            expect(assigns(:categories)).not_to include(@tenant2_category)
          end
        end
      end

      context "with tenant2 context" do
        before do
          host! tenant2.hostname
          setup_tenant_context(tenant2)
        end

        describe "GET /admin/entries" do
          it "only shows entries for the current tenant" do
            get admin_entries_path
            expect(response).to have_http_status(:success)
            expect(assigns(:entries)).to include(@tenant2_listing)
            expect(assigns(:entries)).not_to include(@tenant1_listing)
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

        describe "GET /admin/entries" do
          it "only shows entries for the current tenant" do
            get admin_entries_path
            expect(response).to have_http_status(:success)
            expect(assigns(:entries)).to include(@tenant1_listing)
            expect(assigns(:entries)).not_to include(@tenant2_listing)
          end
        end

        describe "POST /admin/entries" do
          it "creates entry for current tenant" do
          expect {
            post admin_entries_path, params: {
              entry: {
                category_id: @tenant1_category.id,
                url_raw: "https://example.com/test",
                title: "Test Entry",
                description: "Test description"
              }
            }
          }.to change { tenant1.entries.count }.by(1)

          new_entry = tenant1.entries.last
          expect(new_entry.title).to eq("Test Entry")
          expect(new_entry.category).to eq(@tenant1_category)
          expect(new_entry.tenant).to eq(tenant1)
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

        describe "GET /admin/entries" do
          it "redirects with access denied" do
            get admin_entries_path
            expect(response).to redirect_to(root_path)
            expect(flash[:alert]).to eq("Access denied. Admin privileges required.")
          end
        end
      end
    end
  end

  describe 'monetisation actions' do
    let!(:category) { create(:category, :news, tenant: tenant1, site: site1) }
    let!(:entry) { create(:entry, :directory, tenant: tenant1, site: site1, category: category) }

    before do
      sign_in admin_user
      host! tenant1.hostname
      setup_tenant_context(tenant1)
    end

    describe 'POST /admin/entries/:id/feature' do
      it 'sets featured dates' do
        post feature_admin_entry_path(entry)

        entry.reload
        expect(entry.featured_from).to be_within(1.second).of(Time.current)
        expect(entry.featured_until).to be_within(1.day).of(30.days.from_now)
        expect(entry.featured_by).to eq(admin_user)
      end

      it 'redirects with success notice' do
        post feature_admin_entry_path(entry)

        expect(response).to redirect_to(admin_entry_path(entry))
        expect(flash[:notice]).to eq(I18n.t('admin.listings.featured'))
      end

      it 'allows custom featured_until date' do
        future_date = 60.days.from_now
        post feature_admin_entry_path(entry), params: { featured_until: future_date }

        entry.reload
        expect(entry.featured_until).to be_within(1.second).of(future_date)
      end

      it 'makes entry featured?' do
        expect(entry).not_to be_featured
        post feature_admin_entry_path(entry)

        entry.reload
        expect(entry).to be_featured
      end
    end

    describe 'POST /admin/entries/:id/unfeature' do
      let!(:featured_listing) do
        create(:entry, :directory, :featured, tenant: tenant1, site: site1, category: category)
      end

      it 'clears featured dates' do
        expect(featured_listing).to be_featured

        post unfeature_admin_entry_path(featured_listing)

        featured_listing.reload
        expect(featured_listing.featured_from).to be_nil
        expect(featured_listing.featured_until).to be_nil
        expect(featured_listing.featured_by).to be_nil
      end

      it 'redirects with success notice' do
        post unfeature_admin_entry_path(featured_listing)

        expect(response).to redirect_to(admin_entry_path(featured_listing))
        expect(flash[:notice]).to eq(I18n.t('admin.listings.unfeatured'))
      end

      it 'makes entry not featured?' do
        post unfeature_admin_entry_path(featured_listing)

        featured_listing.reload
        expect(featured_listing).not_to be_featured
      end
    end

    describe 'POST /admin/entries/:id/extend_expiry' do
      context 'with existing expiry' do
        let!(:job_listing) do
          create(:entry, :directory, :job, tenant: tenant1, site: site1, category: category,
                 expires_at: 10.days.from_now)
        end

        it 'extends expiry by 30 days from current expiry' do
          original_expiry = job_listing.expires_at
          post extend_expiry_admin_entry_path(job_listing)

          job_listing.reload
          expect(job_listing.expires_at).to be_within(1.second).of(original_expiry + 30.days)
        end

        it 'redirects with success notice' do
          post extend_expiry_admin_entry_path(job_listing)

          expect(response).to redirect_to(admin_entry_path(job_listing))
          expect(flash[:notice]).to eq(I18n.t('admin.listings.expiry_extended'))
        end
      end

      context 'without existing expiry' do
        it 'sets expiry to 30 days from now' do
          post extend_expiry_admin_entry_path(entry)

          entry.reload
          expect(entry.expires_at).to be_within(1.day).of(30.days.from_now)
        end
      end

      context 'with custom expiry date' do
        it 'sets custom expiry date' do
          future_date = 90.days.from_now
          post extend_expiry_admin_entry_path(entry), params: { expires_at: future_date }

          entry.reload
          expect(entry.expires_at).to be_within(1.second).of(future_date)
        end
      end

      context 'with expired entry' do
        let!(:expired_listing) do
          create(:entry, :directory, :expired, tenant: tenant1, site: site1, category: category)
        end

        it 'extends expiry and makes entry not expired' do
          expect(expired_listing).to be_expired

          post extend_expiry_admin_entry_path(expired_listing)

          expired_listing.reload
          expect(expired_listing).not_to be_expired
        end
      end
    end

    describe 'PATCH /admin/entries/:id with monetisation fields' do
      it 'updates affiliate_url_template' do
        patch admin_entry_path(entry), params: {
          entry: { affiliate_url_template: 'https://affiliate.example.com?url={url}' }
        }

        entry.reload
        expect(entry.affiliate_url_template).to eq('https://affiliate.example.com?url={url}')
      end

      it 'updates affiliate_attribution' do
        patch admin_entry_path(entry), params: {
          entry: { affiliate_attribution: { source: 'curated', medium: 'affiliate' } }
        }

        entry.reload
        expect(entry.affiliate_attribution).to eq({ 'source' => 'curated', 'medium' => 'affiliate' })
      end

      it 'updates listing_type' do
        patch admin_entry_path(entry), params: {
          entry: { listing_type: 'job' }
        }

        entry.reload
        expect(entry).to be_job
      end

      it 'updates job-specific fields' do
        patch admin_entry_path(entry), params: {
          entry: {
            listing_type: 'job',
            company: 'Acme Corp',
            location: 'Remote',
            salary_range: '$100k-$150k',
            apply_url: 'https://jobs.example.com/apply'
          }
        }

        entry.reload
        expect(entry.company).to eq('Acme Corp')
        expect(entry.location).to eq('Remote')
        expect(entry.salary_range).to eq('$100k-$150k')
        expect(entry.apply_url).to eq('https://jobs.example.com/apply')
      end

      it 'updates paid status and payment reference' do
        patch admin_entry_path(entry), params: {
          entry: { paid: true, payment_reference: 'pay_abc123' }
        }

        entry.reload
        expect(entry).to be_paid
        expect(entry.payment_reference).to eq('pay_abc123')
      end

      it 'updates featured dates directly' do
        featured_from = 1.day.ago
        featured_until = 30.days.from_now

        patch admin_entry_path(entry), params: {
          entry: { featured_from: featured_from, featured_until: featured_until }
        }

        entry.reload
        expect(entry.featured_from).to be_within(1.second).of(featured_from)
        expect(entry.featured_until).to be_within(1.second).of(featured_until)
      end

      it 'updates expires_at directly' do
        expires_at = 60.days.from_now

        patch admin_entry_path(entry), params: {
          entry: { expires_at: expires_at }
        }

        entry.reload
        expect(entry.expires_at).to be_within(1.second).of(expires_at)
      end
    end

    describe 'tenant isolation for monetisation actions' do
      let!(:other_category) do
        ActsAsTenant.without_tenant do
          create(:category, :news, tenant: tenant2, site: site2)
        end
      end

      let!(:other_entry) do
        ActsAsTenant.without_tenant do
          create(:entry, :directory, tenant: tenant2, site: site2, category: other_category)
        end
      end

      it 'cannot feature entry from different tenant' do
        post feature_admin_entry_path(other_entry)
        expect(response).to have_http_status(:not_found)
      end

      it 'cannot unfeature entry from different tenant' do
        post unfeature_admin_entry_path(other_entry)
        expect(response).to have_http_status(:not_found)
      end

      it 'cannot extend expiry for entry from different tenant' do
        post extend_expiry_admin_entry_path(other_entry)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'scheduling actions' do
    let!(:category) { create(:category, :news, tenant: tenant1, site: site1) }

    before do
      sign_in admin_user
      host! tenant1.hostname
      setup_tenant_context(tenant1)
    end

    describe 'POST /admin/entries with scheduling' do
      it 'creates a published entry when publish_action is publish' do
        freeze_time do
          post admin_entries_path, params: {
            entry: {
              category_id: category.id,
              url_raw: "https://example.com/published",
              title: "Published Entry",
              description: "Test description",
              publish_action: "publish"
            }
          }

          new_entry = tenant1.entries.last
          expect(new_entry.published_at).to be_within(1.second).of(Time.current)
          expect(new_entry.scheduled_for).to be_nil
        end
      end

      it 'creates a scheduled entry when publish_action is schedule' do
        future_time = 1.day.from_now

        post admin_entries_path, params: {
          entry: {
            category_id: category.id,
            url_raw: "https://example.com/scheduled",
            title: "Scheduled Entry",
            description: "Test description",
            publish_action: "schedule",
            scheduled_for: future_time
          }
        }

        new_entry = tenant1.entries.last
        expect(new_entry.published_at).to be_nil
        expect(new_entry.scheduled_for).to be_within(1.second).of(future_time)
        expect(new_entry).to be_scheduled
      end

      it 'creates a draft entry when publish_action is draft' do
        post admin_entries_path, params: {
          entry: {
            category_id: category.id,
            url_raw: "https://example.com/draft",
            title: "Draft Entry",
            description: "Test description",
            publish_action: "draft"
          }
        }

        new_entry = tenant1.entries.last
        expect(new_entry.published_at).to be_nil
        expect(new_entry.scheduled_for).to be_nil
      end
    end

    describe 'PATCH /admin/entries/:id with scheduling' do
      let!(:entry) { create(:entry, :directory, tenant: tenant1, site: site1, category: category) }

      it 'schedules a published entry' do
        future_time = 2.days.from_now

        patch admin_entry_path(entry), params: {
          entry: {
            publish_action: "schedule",
            scheduled_for: future_time
          }
        }

        entry.reload
        expect(entry.published_at).to be_nil
        expect(entry.scheduled_for).to be_within(1.second).of(future_time)
      end

      it 'publishes a scheduled entry' do
        scheduled_listing = create(:entry, :directory, :scheduled, tenant: tenant1, site: site1, category: category)

        freeze_time do
          patch admin_entry_path(scheduled_listing), params: {
            entry: { publish_action: "publish" }
          }

          scheduled_listing.reload
          expect(scheduled_listing.published_at).to be_within(1.second).of(Time.current)
          expect(scheduled_listing.scheduled_for).to be_nil
        end
      end

      it 'unschedules to draft' do
        scheduled_listing = create(:entry, :directory, :scheduled, tenant: tenant1, site: site1, category: category)

        patch admin_entry_path(scheduled_listing), params: {
          entry: { publish_action: "draft" }
        }

        scheduled_listing.reload
        expect(scheduled_listing.published_at).to be_nil
        expect(scheduled_listing.scheduled_for).to be_nil
      end
    end

    describe 'POST /admin/entries/:id/unschedule' do
      let!(:scheduled_listing) do
        create(:entry, :directory, :scheduled, tenant: tenant1, site: site1, category: category)
      end

      it 'clears scheduled_for' do
        expect(scheduled_listing).to be_scheduled

        post unschedule_admin_entry_path(scheduled_listing)

        scheduled_listing.reload
        expect(scheduled_listing.scheduled_for).to be_nil
      end

      it 'does not publish the entry' do
        post unschedule_admin_entry_path(scheduled_listing)

        scheduled_listing.reload
        expect(scheduled_listing.published_at).to be_nil
      end

      it 'redirects with success notice' do
        post unschedule_admin_entry_path(scheduled_listing)

        expect(response).to redirect_to(admin_entry_path(scheduled_listing))
        expect(flash[:notice]).to eq(I18n.t('admin.listings.unscheduled'))
      end
    end

    describe 'POST /admin/entries/:id/publish_now' do
      let!(:scheduled_listing) do
        create(:entry, :directory, :scheduled, tenant: tenant1, site: site1, category: category)
      end

      it 'publishes the entry immediately' do
        freeze_time do
          post publish_now_admin_entry_path(scheduled_listing)

          scheduled_listing.reload
          expect(scheduled_listing.published_at).to be_within(1.second).of(Time.current)
        end
      end

      it 'clears scheduled_for' do
        post publish_now_admin_entry_path(scheduled_listing)

        scheduled_listing.reload
        expect(scheduled_listing.scheduled_for).to be_nil
      end

      it 'redirects with success notice' do
        post publish_now_admin_entry_path(scheduled_listing)

        expect(response).to redirect_to(admin_entry_path(scheduled_listing))
        expect(flash[:notice]).to eq(I18n.t('admin.listings.published_now'))
      end
    end

    describe 'tenant isolation for scheduling actions' do
      let!(:other_category) do
        ActsAsTenant.without_tenant do
          create(:category, :news, tenant: tenant2, site: site2)
        end
      end

      let!(:other_scheduled_listing) do
        ActsAsTenant.without_tenant do
          create(:entry, :directory, :scheduled, tenant: tenant2, site: site2, category: other_category)
        end
      end

      it 'cannot unschedule entry from different tenant' do
        post unschedule_admin_entry_path(other_scheduled_listing)
        expect(response).to have_http_status(:not_found)
      end

      it 'cannot publish_now entry from different tenant' do
        post publish_now_admin_entry_path(other_scheduled_listing)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
