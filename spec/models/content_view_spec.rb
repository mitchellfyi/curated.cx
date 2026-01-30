# frozen_string_literal: true

# == Schema Information
#
# Table name: content_views
#
#  id              :bigint           not null, primary key
#  viewed_at       :datetime         not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  content_item_id :bigint           not null
#  site_id         :bigint           not null
#  user_id         :bigint           not null
#
# Indexes
#
#  index_content_views_on_content_item_id       (content_item_id)
#  index_content_views_on_site_id               (site_id)
#  index_content_views_on_user_id               (user_id)
#  index_content_views_on_user_site_viewed_at   (user_id,site_id,viewed_at DESC)
#  index_content_views_uniqueness               (site_id,user_id,content_item_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (content_item_id => content_items.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (user_id => users.id)
#
require "rails_helper"

RSpec.describe ContentView, type: :model do
  let(:tenant) { create(:tenant) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:source) { create(:source, site: site) }
  let(:content_item) { create(:content_item, site: site, source: source) }
  let(:user) { create(:user) }

  before do
    Current.site = site
  end

  describe "associations" do
    it { should belong_to(:user) }
    it { should belong_to(:content_item) }
    it { should belong_to(:site) }
  end

  describe "validations" do
    context "uniqueness" do
      it "validates uniqueness of user_id scoped to site and content_item" do
        create(:content_view, content_item: content_item, user: user, site: site)

        duplicate = build(:content_view, content_item: content_item, user: user, site: site)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:user_id]).to include("has already viewed this content")
      end

      it "allows same user to view different content items" do
        create(:content_view, content_item: content_item, user: user, site: site)

        other_content_item = create(:content_item, site: site, source: source)
        other_view = build(:content_view, content_item: other_content_item, user: user, site: site)
        expect(other_view).to be_valid
      end

      it "allows different users to view the same content item" do
        create(:content_view, content_item: content_item, user: user, site: site)

        other_user = create(:user)
        other_view = build(:content_view, content_item: content_item, user: other_user, site: site)
        expect(other_view).to be_valid
      end
    end
  end

  describe "scopes" do
    describe ".recent" do
      it "orders by viewed_at descending" do
        old_view = create(:content_view, content_item: content_item, user: user, site: site, viewed_at: 2.days.ago)

        other_content_item = create(:content_item, site: site, source: source)
        other_user = create(:user)
        new_view = create(:content_view, content_item: other_content_item, user: other_user, site: site, viewed_at: 1.hour.ago)

        expect(ContentView.recent.first).to eq(new_view)
        expect(ContentView.recent.last).to eq(old_view)
      end
    end

    describe ".for_user" do
      it "returns views for the specified user" do
        view1 = create(:content_view, content_item: content_item, user: user, site: site)

        other_user = create(:user)
        other_content_item = create(:content_item, site: site, source: source)
        view2 = create(:content_view, content_item: other_content_item, user: other_user, site: site)

        expect(ContentView.for_user(user)).to include(view1)
        expect(ContentView.for_user(user)).not_to include(view2)
      end
    end

    describe ".since" do
      it "returns views since the specified time" do
        old_view = create(:content_view, content_item: content_item, user: user, site: site, viewed_at: 10.days.ago)

        other_content_item = create(:content_item, site: site, source: source)
        other_user = create(:user)
        recent_view = create(:content_view, content_item: other_content_item, user: other_user, site: site, viewed_at: 1.day.ago)

        views_since = ContentView.since(5.days.ago)
        expect(views_since).to include(recent_view)
        expect(views_since).not_to include(old_view)
      end
    end
  end

  describe "site scoping" do
    let(:other_tenant) { create(:tenant) }
    let(:other_site) { create(:site, tenant: other_tenant) }
    let(:other_source) { create(:source, site: other_site) }
    let(:other_content_item) { create(:content_item, site: other_site, source: other_source) }

    it "scopes queries to current site" do
      view1 = create(:content_view, content_item: content_item, user: user, site: site)

      Current.site = other_site
      view2 = create(:content_view, content_item: other_content_item, user: create(:user), site: other_site)

      Current.site = site
      expect(ContentView.all).to include(view1)
      expect(ContentView.all).not_to include(view2)
    end

    it "prevents accessing views from other sites" do
      view = create(:content_view, content_item: content_item, user: user, site: site)

      Current.site = other_site
      expect {
        ContentView.find(view.id)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "factory" do
    it "creates a valid content view" do
      view = build(:content_view)
      expect(view).to be_valid
    end

    it "supports recent trait" do
      view = build(:content_view, :recent)
      expect(view.viewed_at).to be_within(2.hours).of(1.hour.ago)
    end

    it "supports old trait" do
      view = build(:content_view, :old)
      expect(view.viewed_at).to be_within(1.day).of(30.days.ago)
    end
  end
end
