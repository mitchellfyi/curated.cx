# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscussionPost, type: :model do
  let(:tenant) { create(:tenant) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:user) { create(:user) }
  let(:discussion) { create(:discussion, site: site, user: user) }

  before do
    Current.site = site
  end

  describe "associations" do
    it { should belong_to(:user) }
    it { should belong_to(:discussion) }
    it { should belong_to(:site) }
    it { should belong_to(:parent).class_name("DiscussionPost").optional }
    it { should have_many(:replies).class_name("DiscussionPost").with_foreign_key(:parent_id).dependent(:destroy) }
    it { should have_many(:flags).dependent(:destroy) }
  end

  describe "validations" do
    it { should validate_presence_of(:body) }
    it { should validate_length_of(:body).is_at_most(DiscussionPost::BODY_MAX_LENGTH) }

    context "body length" do
      it "allows body up to max length" do
        post = build(:discussion_post, discussion: discussion, user: user, site: site, body: "a" * DiscussionPost::BODY_MAX_LENGTH)
        expect(post).to be_valid
      end

      it "rejects body exceeding max length" do
        post = build(:discussion_post, discussion: discussion, user: user, site: site, body: "a" * (DiscussionPost::BODY_MAX_LENGTH + 1))
        expect(post).not_to be_valid
        expect(post.errors[:body]).to be_present
      end
    end

    context "parent validation" do
      it "allows parent from same discussion" do
        parent = create(:discussion_post, discussion: discussion, user: user, site: site)
        reply = build(:discussion_post, discussion: discussion, user: user, site: site, parent: parent)

        expect(reply).to be_valid
      end

      it "rejects parent from different discussion" do
        other_discussion = create(:discussion, site: site, user: user)
        parent = create(:discussion_post, discussion: other_discussion, user: user, site: site)
        reply = build(:discussion_post, discussion: discussion, user: user, site: site, parent: parent)

        expect(reply).not_to be_valid
        expect(reply.errors[:parent]).to include("must belong to the same discussion")
      end
    end
  end

  describe "scopes" do
    let!(:root_post) { create(:discussion_post, discussion: discussion, user: user, site: site) }
    let!(:reply) { create(:discussion_post, discussion: discussion, user: create(:user), site: site, parent: root_post) }
    let!(:hidden_post) { create(:discussion_post, :hidden, discussion: discussion, user: create(:user), site: site) }

    describe ".root_posts" do
      it "returns only root posts" do
        expect(DiscussionPost.root_posts).to include(root_post, hidden_post)
        expect(DiscussionPost.root_posts).not_to include(reply)
      end
    end

    describe ".visible" do
      it "returns only visible posts" do
        expect(DiscussionPost.visible).to include(root_post, reply)
        expect(DiscussionPost.visible).not_to include(hidden_post)
      end
    end

    describe ".oldest_first" do
      it "orders by created_at asc" do
        old_post = create(:discussion_post, discussion: discussion, user: create(:user), site: site, created_at: 1.day.ago)
        new_post = create(:discussion_post, discussion: discussion, user: create(:user), site: site, created_at: 1.hour.ago)

        expect(DiscussionPost.oldest_first.first).to eq(old_post)
      end
    end

    describe ".recent" do
      it "orders by created_at desc" do
        old_post = create(:discussion_post, discussion: discussion, user: create(:user), site: site, created_at: 1.day.ago)
        new_post = create(:discussion_post, discussion: discussion, user: create(:user), site: site, created_at: 1.minute.ago)

        recent_posts = DiscussionPost.recent
        old_post_index = recent_posts.to_a.index(old_post)
        new_post_index = recent_posts.to_a.index(new_post)
        expect(new_post_index).to be < old_post_index
      end
    end
  end

  describe "instance methods" do
    describe "#root?" do
      it "returns true for root posts" do
        post = build(:discussion_post, parent: nil)
        expect(post.root?).to be true
      end

      it "returns false for replies" do
        parent = create(:discussion_post, discussion: discussion, user: user, site: site)
        reply = build(:discussion_post, discussion: discussion, parent: parent)
        expect(reply.root?).to be false
      end
    end

    describe "#reply?" do
      it "returns true for replies" do
        parent = create(:discussion_post, discussion: discussion, user: user, site: site)
        reply = build(:discussion_post, discussion: discussion, parent: parent)
        expect(reply.reply?).to be true
      end

      it "returns false for root posts" do
        post = build(:discussion_post, parent: nil)
        expect(post.reply?).to be false
      end
    end

    describe "#edited?" do
      it "returns true when edited_at is present" do
        post = build(:discussion_post, :edited)
        expect(post.edited?).to be true
      end

      it "returns false when edited_at is nil" do
        post = build(:discussion_post, edited_at: nil)
        expect(post.edited?).to be false
      end
    end

    describe "#hidden?" do
      it "returns true when hidden_at is present" do
        post = build(:discussion_post, :hidden)
        expect(post.hidden?).to be true
      end

      it "returns false when hidden_at is nil" do
        post = build(:discussion_post, hidden_at: nil)
        expect(post.hidden?).to be false
      end
    end

    describe "#mark_as_edited!" do
      it "sets edited_at to current time" do
        post = create(:discussion_post, discussion: discussion, user: user, site: site)
        expect(post.edited_at).to be_nil

        freeze_time do
          post.mark_as_edited!
          expect(post.reload.edited_at).to eq(Time.current)
        end
      end
    end
  end

  describe "callbacks" do
    describe "after_create :touch_discussion_last_post" do
      it "updates discussion's last_post_at when post is created" do
        discussion.update!(last_post_at: 1.day.ago)

        freeze_time do
          create(:discussion_post, discussion: discussion, user: user, site: site)
          expect(discussion.reload.last_post_at).to eq(Time.current)
        end
      end
    end
  end

  describe "counter cache" do
    it "increments posts_count on discussion when post is created" do
      expect {
        create(:discussion_post, discussion: discussion, user: user, site: site)
      }.to change { discussion.reload.posts_count }.by(1)
    end

    it "decrements posts_count on discussion when post is destroyed" do
      post = create(:discussion_post, discussion: discussion, user: user, site: site)
      discussion.reload

      expect {
        post.destroy
      }.to change { discussion.reload.posts_count }.by(-1)
    end
  end

  describe "threading" do
    let!(:root) { create(:discussion_post, discussion: discussion, user: user, site: site) }
    let!(:reply1) { create(:discussion_post, discussion: discussion, user: create(:user), site: site, parent: root) }
    let!(:reply2) { create(:discussion_post, discussion: discussion, user: create(:user), site: site, parent: root) }

    it "has_many replies" do
      expect(root.replies).to include(reply1, reply2)
    end

    it "destroys replies when parent is destroyed" do
      expect {
        root.destroy
      }.to change(DiscussionPost, :count).by(-3)
    end
  end

  describe "site scoping" do
    let(:other_tenant) { create(:tenant) }
    let(:other_site) { create(:site, tenant: other_tenant) }
    let(:other_discussion) { create(:discussion, site: other_site, user: create(:user)) }

    it "scopes queries to current site" do
      post1 = create(:discussion_post, discussion: discussion, user: user, site: site)

      Current.site = other_site
      post2 = create(:discussion_post, discussion: other_discussion, user: create(:user), site: other_site)

      Current.site = site
      expect(DiscussionPost.all).to include(post1)
      expect(DiscussionPost.all).not_to include(post2)
    end

    it "prevents accessing posts from other sites" do
      post = create(:discussion_post, discussion: discussion, user: user, site: site)

      Current.site = other_site
      expect {
        DiscussionPost.find(post.id)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "factory" do
    it "creates a valid discussion post" do
      post = build(:discussion_post)
      expect(post).to be_valid
    end

    it "supports reply trait" do
      post = create(:discussion_post, :reply, discussion: discussion, site: site, user: user)
      expect(post.parent).to be_present
      expect(post.reply?).to be true
    end

    it "supports edited trait" do
      post = build(:discussion_post, :edited)
      expect(post.edited?).to be true
    end

    it "supports hidden trait" do
      post = build(:discussion_post, :hidden)
      expect(post.hidden?).to be true
    end

    it "supports long trait" do
      post = build(:discussion_post, :long)
      expect(post.body.length).to be > 500
    end
  end
end
