# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Feed", type: :request do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:source) { create(:source, site: site) }

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
  end

  describe "GET /feed" do
    context "with published content items" do
      let!(:entries) do
        items = create_list(:entry, :feed, 5, :published, site: site, source: source)
        items.each_with_index do |item, i|
          item.update_columns(
            topic_tags: [ "tech", "ai" ],
            content_type: "article",
            upvotes_count: i * 10,
            comments_count: i * 5
          )
        end
        items
      end

      it "returns http success" do
        get feed_index_path

        expect(response).to have_http_status(:success)
      end

      it "renders the index template" do
        get feed_index_path

        expect(response).to render_template(:index)
      end

      it "assigns entries" do
        get feed_index_path

        expect(assigns(:entries)).to be_present
        expect(assigns(:entries).count).to eq(5)
      end

      it "assigns taxonomies for filter UI" do
        taxonomy = create(:taxonomy, site: site)

        get feed_index_path

        expect(assigns(:taxonomies)).to be_present
      end

      it "assigns content_types for filter UI" do
        get feed_index_path

        expect(assigns(:content_types)).to include("article")
      end
    end

    context "filtering" do
      let!(:tech_article) do
        item = create(:entry, :feed, :published, site: site, source: source)
        item.update_columns(topic_tags: [ "tech" ], content_type: "article")
        item
      end

      let!(:sports_video) do
        item = create(:entry, :feed, :published, site: site, source: source)
        item.update_columns(topic_tags: [ "sports" ], content_type: "video")
        item
      end

      it "filters by tag parameter" do
        get feed_index_path, params: { tag: "tech" }

        expect(assigns(:entries)).to include(tech_article)
        expect(assigns(:entries)).not_to include(sports_video)
      end

      it "filters by content_type parameter" do
        get feed_index_path, params: { content_type: "video" }

        expect(assigns(:entries)).not_to include(tech_article)
        expect(assigns(:entries)).to include(sports_video)
      end

      it "supports combined filters" do
        get feed_index_path, params: { tag: "tech", content_type: "article" }

        expect(assigns(:entries)).to contain_exactly(tech_article)
      end
    end

    context "sorting" do
      let!(:old_item) do
        item = create(:entry, :feed, :published, site: site, source: source, published_at: 2.days.ago)
        item.update_columns(upvotes_count: 100, comments_count: 50)
        item
      end

      let!(:new_item) do
        item = create(:entry, :feed, :published, site: site, source: source, published_at: 1.hour.ago)
        item.update_columns(upvotes_count: 0, comments_count: 0)
        item
      end

      it "supports latest sort" do
        get feed_index_path, params: { sort: "latest" }

        expect(assigns(:entries).first).to eq(new_item)
      end

      it "supports top_week sort" do
        get feed_index_path, params: { sort: "top_week" }

        expect(assigns(:entries).first).to eq(old_item)
      end

      it "supports ranked sort" do
        get feed_index_path, params: { sort: "ranked" }

        expect(assigns(:entries)).to be_present
      end
    end

    context "pagination" do
      before do
        create_list(:entry, :feed, 25, :published, site: site, source: source)
      end

      it "limits results to 20 per page" do
        get feed_index_path

        expect(assigns(:entries).count).to eq(20)
      end

      it "supports page parameter" do
        get feed_index_path, params: { page: 2 }

        expect(assigns(:entries).count).to eq(5)
      end

      it "handles invalid page gracefully" do
        get feed_index_path, params: { page: -1 }

        expect(response).to have_http_status(:success)
        expect(assigns(:entries).count).to eq(20)
      end
    end

    context "when tenant requires login" do
      let(:private_tenant) { create(:tenant, :private_access) }

      before do
        host! private_tenant.hostname
        setup_tenant_context(private_tenant)
      end

      context "when user is not signed in" do
        it "redirects to sign in" do
          get feed_index_path

          expect(response).to redirect_to(new_user_session_path)
        end
      end

      context "when user is signed in" do
        let(:user) { create(:user) }

        before do
          sign_in user
          user.add_role(:viewer, private_tenant)
        end

        it "returns http success" do
          get feed_index_path

          expect(response).to have_http_status(:success)
        end
      end
    end

    context "meta tags" do
      it "sets correct page meta tags" do
        get feed_index_path

        expect(response.body).to include("<title>")
        # The canonical URL should be present
        expect(response.body).to include("canonical")
      end

      it "includes RSS alternate link" do
        get feed_index_path

        expect(response.body).to include("application/rss+xml")
      end
    end
  end

  describe "GET /feed/rss" do
    let!(:entries) do
      items = create_list(:entry, :feed, 5, :published, site: site, source: source)
      items.each do |item|
        item.update_columns(
          title: "Test Article #{item.id}",
          description: "Test description for article #{item.id}",
          ai_summary: "AI summary for article #{item.id}"
        )
      end
      items
    end

    it "returns RSS format" do
      get feed_rss_path(format: :rss)

      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("application/rss+xml")
    end

    it "returns valid RSS XML" do
      get feed_rss_path(format: :rss)

      expect(response.body).to include('<?xml version="1.0" encoding="UTF-8"?>')
      expect(response.body).to include("<rss")
      expect(response.body).to include("<channel>")
    end

    it "includes channel metadata" do
      get feed_rss_path(format: :rss)

      expect(response.body).to include("<title>")
      expect(response.body).to include("<link>")
      expect(response.body).to include("<description>")
    end

    it "includes items with required fields" do
      get feed_rss_path(format: :rss)

      expect(response.body).to include("<item>")
      expect(response.body).to include("<pubDate>")
      expect(response.body).to include("<guid ")  # guid has isPermaLink attribute
    end

    it "limits to MAX_RSS_ITEMS" do
      create_list(:entry, :feed, 60, :published, site: site, source: source)

      get feed_rss_path(format: :rss)

      # Should not exceed 50 items
      expect(response.body.scan("<item>").count).to be <= 50
    end

    it "sorts by latest" do
      old_item = create(:entry, :feed, :published, site: site, source: source, published_at: 2.days.ago)
      new_item = create(:entry, :feed, :published, site: site, source: source, published_at: 1.hour.ago)

      get feed_rss_path(format: :rss)

      # The newest item should appear first in the feed
      new_item_position = response.body.index(new_item.url_canonical.to_s)
      old_item_position = response.body.index(old_item.url_canonical.to_s)

      expect(new_item_position).to be < old_item_position
    end

    context "when tenant requires login" do
      let(:private_tenant) { create(:tenant, :private_access) }

      before do
        host! private_tenant.hostname
        setup_tenant_context(private_tenant)
      end

      it "redirects to sign in when not authenticated" do
        get feed_rss_path(format: :rss)

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "authorization" do
    it "uses EntryPolicy for index action" do
      expect_any_instance_of(EntryPolicy).to receive(:index?).and_return(true)

      get feed_index_path
    end

    it "uses EntryPolicy for rss action" do
      expect_any_instance_of(EntryPolicy).to receive(:index?).and_return(true)

      get feed_rss_path(format: :rss)
    end
  end

  describe "site isolation" do
    let!(:other_item) do
      ActsAsTenant.without_tenant do
        other_tenant = create(:tenant, :enabled)
        other_site = other_tenant.sites.first
        other_source = create(:source, site: other_site, tenant: other_tenant)
        create(:entry, :feed, :published, site: other_site, source: other_source)
      end
    end
    let!(:our_item) { create(:entry, :feed, :published, site: site, source: source) }

    it "only shows content from current site" do
      get feed_index_path

      expect(assigns(:entries)).to include(our_item)
      expect(assigns(:entries)).not_to include(other_item)
    end
  end
end
