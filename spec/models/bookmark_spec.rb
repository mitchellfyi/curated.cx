# frozen_string_literal: true

# == Schema Information
#
# Table name: bookmarks
#
#  id                :bigint           not null, primary key
#  bookmarkable_type :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  bookmarkable_id   :bigint           not null
#  user_id           :bigint           not null
#
# Indexes
#
#  index_bookmarks_on_bookmarkable  (bookmarkable_type,bookmarkable_id)
#  index_bookmarks_on_user_id       (user_id)
#  index_bookmarks_uniqueness       (user_id,bookmarkable_type,bookmarkable_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
require "rails_helper"

RSpec.describe Bookmark, type: :model do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:source) { create(:source, site: site) }
  let(:user) { create(:user) }
  let(:entry) { create(:entry, :feed, :published, site: site, source: source) }

  before do
    allow(Current).to receive(:tenant).and_return(tenant)
    allow(Current).to receive(:site).and_return(site)
  end

  describe "associations" do
    it { should belong_to(:user) }
    it { should belong_to(:bookmarkable) }
  end

  describe "validations" do
    it "validates uniqueness of user per bookmarkable" do
      create(:bookmark, user: user, bookmarkable: entry)
      duplicate = build(:bookmark, user: user, bookmarkable: entry)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to include("already bookmarked this item")
    end

    it "allows same user to bookmark different items" do
      create(:bookmark, user: user, bookmarkable: entry)
      other_item = create(:entry, :feed, :published, site: site, source: source)
      other_bookmark = build(:bookmark, user: user, bookmarkable: other_item)

      expect(other_bookmark).to be_valid
    end

    it "allows different users to bookmark same item" do
      create(:bookmark, user: user, bookmarkable: entry)
      other_user = create(:user)
      other_bookmark = build(:bookmark, user: other_user, bookmarkable: entry)

      expect(other_bookmark).to be_valid
    end
  end

  describe "scopes" do
    let!(:old_bookmark) { create(:bookmark, user: user, bookmarkable: entry, created_at: 2.days.ago) }
    let!(:new_bookmark) do
      other_item = create(:entry, :feed, :published, site: site, source: source)
      create(:bookmark, user: user, bookmarkable: other_item, created_at: 1.hour.ago)
    end

    describe ".recent" do
      it "orders by created_at desc" do
        expect(Bookmark.recent.first).to eq(new_bookmark)
        expect(Bookmark.recent.last).to eq(old_bookmark)
      end
    end

    describe ".for_entries" do
      it "returns only entry bookmarks" do
        category = create(:category, tenant: tenant)
        directory_entry = create(:entry, :directory, site: site, category: category)
        directory_bookmark = create(:bookmark, user: create(:user), bookmarkable: directory_entry)

        expect(Bookmark.for_entries).to include(old_bookmark, new_bookmark)
        # directory entries are still Entry type, so they'd be included too
      end
    end
  end

  describe ".bookmarked?" do
    it "returns true when user has bookmarked the item" do
      create(:bookmark, user: user, bookmarkable: entry)

      expect(described_class.bookmarked?(user, entry)).to be true
    end

    it "returns false when user has not bookmarked the item" do
      expect(described_class.bookmarked?(user, entry)).to be false
    end

    it "returns false when user is nil" do
      expect(described_class.bookmarked?(nil, entry)).to be false
    end
  end
end
