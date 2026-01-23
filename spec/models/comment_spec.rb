# frozen_string_literal: true

# == Schema Information
#
# Table name: comments
#
#  id              :bigint           not null, primary key
#  body            :text             not null
#  edited_at       :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  content_item_id :bigint           not null
#  parent_id       :bigint
#  site_id         :bigint           not null
#  user_id         :bigint           not null
#
# Indexes
#
#  index_comments_on_content_item_and_parent  (content_item_id,parent_id)
#  index_comments_on_content_item_id          (content_item_id)
#  index_comments_on_parent_id                (parent_id)
#  index_comments_on_site_and_user            (site_id,user_id)
#  index_comments_on_site_id                  (site_id)
#  index_comments_on_user_id                  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (content_item_id => content_items.id)
#  fk_rails_...  (parent_id => comments.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (user_id => users.id)
#
require "rails_helper"

RSpec.describe Comment, type: :model do
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
    it { should belong_to(:parent).class_name("Comment").optional }
    it { should have_many(:replies).class_name("Comment").with_foreign_key(:parent_id).dependent(:destroy) }
  end

  describe "validations" do
    it { should validate_presence_of(:body) }
    it { should validate_length_of(:body).is_at_most(Comment::BODY_MAX_LENGTH) }

    context "parent validation" do
      it "allows parent from same content item" do
        parent = create(:comment, content_item: content_item, user: user, site: site)
        reply = build(:comment, content_item: content_item, user: user, site: site, parent: parent)

        expect(reply).to be_valid
      end

      it "rejects parent from different content item" do
        other_content_item = create(:content_item, site: site, source: source)
        parent = create(:comment, content_item: other_content_item, user: user, site: site)
        reply = build(:comment, content_item: content_item, user: user, site: site, parent: parent)

        expect(reply).not_to be_valid
        expect(reply.errors[:parent]).to include("must belong to the same content item")
      end
    end

    context "body length" do
      it "allows body up to max length" do
        comment = build(:comment, content_item: content_item, user: user, site: site, body: "a" * Comment::BODY_MAX_LENGTH)
        expect(comment).to be_valid
      end

      it "rejects body exceeding max length" do
        comment = build(:comment, content_item: content_item, user: user, site: site, body: "a" * (Comment::BODY_MAX_LENGTH + 1))
        expect(comment).not_to be_valid
        expect(comment.errors[:body]).to be_present
      end
    end
  end

  describe "scopes" do
    let!(:root_comment) { create(:comment, content_item: content_item, user: user, site: site) }
    let!(:reply) { create(:comment, content_item: content_item, user: create(:user), site: site, parent: root_comment) }

    describe ".root_comments" do
      it "returns only root comments" do
        expect(Comment.root_comments).to include(root_comment)
        expect(Comment.root_comments).not_to include(reply)
      end
    end

    describe ".replies_to" do
      it "returns replies to the specified comment" do
        expect(Comment.replies_to(root_comment)).to include(reply)
        expect(Comment.replies_to(root_comment)).not_to include(root_comment)
      end
    end

    describe ".recent" do
      it "orders by created_at desc" do
        # Use future timestamps to ensure these are the most recent comments
        old_comment = create(:comment, content_item: content_item, user: create(:user), site: site, created_at: 1.hour.from_now)
        new_comment = create(:comment, content_item: content_item, user: create(:user), site: site, created_at: 2.hours.from_now)

        expect(Comment.recent.first).to eq(new_comment)
      end
    end

    describe ".oldest_first" do
      it "orders by created_at asc" do
        old_comment = create(:comment, content_item: content_item, user: create(:user), site: site, created_at: 1.day.ago)
        new_comment = create(:comment, content_item: content_item, user: create(:user), site: site, created_at: 1.hour.ago)

        expect(Comment.oldest_first.first).to eq(old_comment)
      end
    end

    describe ".for_content_item" do
      it "returns comments for the specified content item" do
        other_content_item = create(:content_item, site: site, source: source)
        other_comment = create(:comment, content_item: other_content_item, user: create(:user), site: site)

        expect(Comment.for_content_item(content_item)).to include(root_comment, reply)
        expect(Comment.for_content_item(content_item)).not_to include(other_comment)
      end
    end
  end

  describe "instance methods" do
    describe "#edited?" do
      it "returns true when edited_at is present" do
        comment = build(:comment, :edited)
        expect(comment.edited?).to be true
      end

      it "returns false when edited_at is nil" do
        comment = build(:comment, edited_at: nil)
        expect(comment.edited?).to be false
      end
    end

    describe "#root?" do
      it "returns true for root comments" do
        comment = build(:comment, parent: nil)
        expect(comment.root?).to be true
      end

      it "returns false for replies" do
        parent = create(:comment, content_item: content_item, user: user, site: site)
        reply = build(:comment, content_item: content_item, parent: parent)
        expect(reply.root?).to be false
      end
    end

    describe "#reply?" do
      it "returns true for replies" do
        parent = create(:comment, content_item: content_item, user: user, site: site)
        reply = build(:comment, content_item: content_item, parent: parent)
        expect(reply.reply?).to be true
      end

      it "returns false for root comments" do
        comment = build(:comment, parent: nil)
        expect(comment.reply?).to be false
      end
    end

    describe "#mark_as_edited!" do
      it "sets edited_at to current time" do
        comment = create(:comment, content_item: content_item, user: user, site: site)
        expect(comment.edited_at).to be_nil

        freeze_time do
          comment.mark_as_edited!
          expect(comment.reload.edited_at).to eq(Time.current)
        end
      end
    end
  end

  describe "threading" do
    let!(:root) { create(:comment, content_item: content_item, user: user, site: site) }
    let!(:reply1) { create(:comment, content_item: content_item, user: create(:user), site: site, parent: root) }
    let!(:reply2) { create(:comment, content_item: content_item, user: create(:user), site: site, parent: root) }

    it "has_many replies" do
      expect(root.replies).to include(reply1, reply2)
    end

    it "destroys replies when parent is destroyed" do
      expect {
        root.destroy
      }.to change(Comment, :count).by(-3)
    end
  end

  describe "site scoping" do
    let(:other_tenant) { create(:tenant) }
    let(:other_site) { create(:site, tenant: other_tenant) }
    let(:other_source) { create(:source, site: other_site) }
    let(:other_content_item) { create(:content_item, site: other_site, source: other_source) }

    it "scopes queries to current site" do
      comment1 = create(:comment, content_item: content_item, user: user, site: site)

      Current.site = other_site
      comment2 = create(:comment, content_item: other_content_item, user: create(:user), site: other_site)

      Current.site = site
      expect(Comment.all).to include(comment1)
      expect(Comment.all).not_to include(comment2)
    end

    it "prevents accessing comments from other sites" do
      comment = create(:comment, content_item: content_item, user: user, site: site)

      Current.site = other_site
      expect {
        Comment.find(comment.id)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "counter cache" do
    it "increments comments_count on content_item when comment is created" do
      expect {
        create(:comment, content_item: content_item, user: user, site: site)
      }.to change { content_item.reload.comments_count }.by(1)
    end

    it "decrements comments_count on content_item when comment is destroyed" do
      comment = create(:comment, content_item: content_item, user: user, site: site)
      content_item.reload

      expect {
        comment.destroy
      }.to change { content_item.reload.comments_count }.by(-1)
    end
  end

  describe "factory" do
    it "creates a valid comment" do
      comment = build(:comment)
      expect(comment).to be_valid
    end

    it "supports reply trait" do
      comment = create(:comment, :reply, content_item: content_item, site: site, user: user)
      expect(comment.parent).to be_present
      expect(comment.reply?).to be true
    end

    it "supports edited trait" do
      comment = build(:comment, :edited)
      expect(comment.edited?).to be true
    end

    it "supports long trait" do
      comment = build(:comment, :long)
      expect(comment.body.length).to be > 500
    end
  end
end
