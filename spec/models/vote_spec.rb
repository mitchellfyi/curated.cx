# frozen_string_literal: true

# == Schema Information
#
# Table name: votes
#
#  id           :bigint           not null, primary key
#  value        :integer          default(1), not null
#  votable_type :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  site_id      :bigint           not null
#  user_id      :bigint           not null
#  votable_id   :bigint           not null
#
# Indexes
#
#  index_votes_on_site_id  (site_id)
#  index_votes_on_user_id  (user_id)
#  index_votes_on_votable  (votable_type,votable_id)
#  index_votes_uniqueness  (site_id,user_id,votable_type,votable_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (user_id => users.id)
#
require "rails_helper"

RSpec.describe Vote, type: :model do
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
    it { should belong_to(:votable) }
    it { should belong_to(:site) }
  end

  describe "validations" do
    subject { build(:vote, votable: content_item, user: user, site: site) }

    it { should validate_presence_of(:value) }
    it { should validate_numericality_of(:value).only_integer }

    context "uniqueness" do
      it "validates uniqueness of user_id scoped to site and votable" do
        create(:vote, votable: content_item, user: user, site: site)

        duplicate = build(:vote, votable: content_item, user: user, site: site)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:user_id]).to include("has already voted on this content")
      end

      it "allows same user to vote on different content items" do
        create(:vote, votable: content_item, user: user, site: site)

        other_content_item = create(:content_item, site: site, source: source)
        other_vote = build(:vote, votable: other_content_item, user: user, site: site)
        expect(other_vote).to be_valid
      end

      it "allows different users to vote on the same content item" do
        create(:vote, votable: content_item, user: user, site: site)

        other_user = create(:user)
        other_vote = build(:vote, votable: content_item, user: other_user, site: site)
        expect(other_vote).to be_valid
      end
    end
  end

  describe "scopes" do
    describe ".for_content_item" do
      it "returns votes for the specified content item" do
        vote1 = create(:vote, votable: content_item, user: user, site: site)
        other_content_item = create(:content_item, site: site, source: source)
        vote2 = create(:vote, votable: other_content_item, user: create(:user), site: site)

        expect(Vote.for_content_item(content_item)).to include(vote1)
        expect(Vote.for_content_item(content_item)).not_to include(vote2)
      end
    end

    describe ".for_note" do
      it "returns votes for the specified note" do
        note = create(:note, :published, site: site, user: user)
        vote1 = create(:vote, votable: note, user: user, site: site)
        vote2 = create(:vote, votable: content_item, user: create(:user), site: site)

        expect(Vote.for_note(note)).to include(vote1)
        expect(Vote.for_note(note)).not_to include(vote2)
      end
    end

    describe ".content_items" do
      it "returns only votes on content items" do
        note = create(:note, :published, site: site, user: user)
        content_vote = create(:vote, votable: content_item, user: user, site: site)
        note_vote = create(:vote, votable: note, user: create(:user), site: site)

        expect(Vote.content_items).to include(content_vote)
        expect(Vote.content_items).not_to include(note_vote)
      end
    end

    describe ".notes" do
      it "returns only votes on notes" do
        note = create(:note, :published, site: site, user: user)
        content_vote = create(:vote, votable: content_item, user: user, site: site)
        note_vote = create(:vote, votable: note, user: create(:user), site: site)

        expect(Vote.notes).to include(note_vote)
        expect(Vote.notes).not_to include(content_vote)
      end
    end

    describe ".by_user" do
      it "returns votes by the specified user" do
        vote1 = create(:vote, votable: content_item, user: user, site: site)
        other_user = create(:user)
        other_content_item = create(:content_item, site: site, source: source)
        vote2 = create(:vote, votable: other_content_item, user: other_user, site: site)

        expect(Vote.by_user(user)).to include(vote1)
        expect(Vote.by_user(user)).not_to include(vote2)
      end
    end
  end

  describe "site scoping" do
    let(:other_tenant) { create(:tenant) }
    let(:other_site) { create(:site, tenant: other_tenant) }
    let(:other_source) { create(:source, site: other_site) }
    let(:other_content_item) { create(:content_item, site: other_site, source: other_source) }

    it "scopes queries to current site" do
      vote1 = create(:vote, votable: content_item, user: user, site: site)

      Current.site = other_site
      vote2 = create(:vote, votable: other_content_item, user: create(:user), site: other_site)

      Current.site = site
      expect(Vote.all).to include(vote1)
      expect(Vote.all).not_to include(vote2)
    end

    it "prevents accessing votes from other sites" do
      vote = create(:vote, votable: content_item, user: user, site: site)

      Current.site = other_site
      expect {
        Vote.find(vote.id)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "counter cache" do
    context "on ContentItem" do
      it "increments upvotes_count on content_item when vote is created" do
        expect {
          create(:vote, votable: content_item, user: user, site: site)
        }.to change { content_item.reload.upvotes_count }.by(1)
      end

      it "decrements upvotes_count on content_item when vote is destroyed" do
        vote = create(:vote, votable: content_item, user: user, site: site)
        content_item.reload

        expect {
          vote.destroy
        }.to change { content_item.reload.upvotes_count }.by(-1)
      end
    end

    context "on Note" do
      let(:note) { create(:note, :published, site: site, user: user) }

      it "increments upvotes_count on note when vote is created" do
        expect {
          create(:vote, votable: note, user: create(:user), site: site)
        }.to change { note.reload.upvotes_count }.by(1)
      end

      it "decrements upvotes_count on note when vote is destroyed" do
        vote = create(:vote, votable: note, user: create(:user), site: site)
        note.reload

        expect {
          vote.destroy
        }.to change { note.reload.upvotes_count }.by(-1)
      end
    end
  end

  describe "polymorphic voting" do
    let(:note) { create(:note, :published, site: site, user: user) }

    it "allows voting on ContentItem" do
      vote = build(:vote, votable: content_item, user: user, site: site)
      expect(vote).to be_valid
      expect(vote.votable_type).to eq("ContentItem")
    end

    it "allows voting on Note" do
      vote = build(:vote, votable: note, user: create(:user), site: site)
      expect(vote).to be_valid
      expect(vote.votable_type).to eq("Note")
    end

    it "allows same user to vote on both ContentItem and Note" do
      create(:vote, votable: content_item, user: user, site: site)
      note_vote = build(:vote, votable: note, user: user, site: site)
      expect(note_vote).to be_valid
    end
  end

  describe "factory" do
    it "creates a valid vote" do
      vote = build(:vote)
      expect(vote).to be_valid
    end

    it "supports downvote trait" do
      vote = build(:vote, :downvote)
      expect(vote.value).to eq(-1)
    end

    it "supports for_note trait" do
      vote = create(:vote, :for_note, site: site, user: user)
      expect(vote.votable_type).to eq("Note")
    end
  end
end
