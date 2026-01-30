# frozen_string_literal: true

require "rails_helper"

RSpec.describe Discussion, type: :model do
  let(:tenant) { create(:tenant) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:user) { create(:user) }

  before do
    Current.site = site
  end

  describe "associations" do
    it { should belong_to(:user) }
    it { should belong_to(:site) }
    it { should belong_to(:locked_by).class_name("User").optional }
    it { should have_many(:posts).class_name("DiscussionPost").dependent(:destroy) }
  end

  describe "validations" do
    it { should validate_presence_of(:title) }
    it { should validate_length_of(:title).is_at_most(Discussion::TITLE_MAX_LENGTH) }
    it { should validate_length_of(:body).is_at_most(Discussion::BODY_MAX_LENGTH) }
    it { should validate_presence_of(:visibility) }

    context "title length" do
      it "allows title up to max length" do
        discussion = build(:discussion, site: site, user: user, title: "a" * Discussion::TITLE_MAX_LENGTH)
        expect(discussion).to be_valid
      end

      it "rejects title exceeding max length" do
        discussion = build(:discussion, site: site, user: user, title: "a" * (Discussion::TITLE_MAX_LENGTH + 1))
        expect(discussion).not_to be_valid
        expect(discussion.errors[:title]).to be_present
      end
    end

    context "body length" do
      it "allows blank body" do
        discussion = build(:discussion, site: site, user: user, body: nil)
        expect(discussion).to be_valid
      end

      it "allows body up to max length" do
        discussion = build(:discussion, site: site, user: user, body: "a" * Discussion::BODY_MAX_LENGTH)
        expect(discussion).to be_valid
      end

      it "rejects body exceeding max length" do
        discussion = build(:discussion, site: site, user: user, body: "a" * (Discussion::BODY_MAX_LENGTH + 1))
        expect(discussion).not_to be_valid
        expect(discussion.errors[:body]).to be_present
      end
    end
  end

  describe "enums" do
    it "defines visibility enum" do
      expect(Discussion.visibilities).to eq({ "public_access" => 0, "subscribers_only" => 1 })
    end

    it "uses visibility prefix for enum methods" do
      discussion = build(:discussion, visibility: :public_access)
      expect(discussion.visibility_public_access?).to be true
      expect(discussion.visibility_subscribers_only?).to be false
    end
  end

  describe "scopes" do
    let!(:pinned_discussion) { create(:discussion, :pinned, site: site, user: user, last_post_at: 1.hour.ago) }
    let!(:regular_discussion) { create(:discussion, site: site, user: user, last_post_at: 2.hours.ago) }
    let!(:subscribers_only_discussion) { create(:discussion, :subscribers_only, site: site, user: user) }
    let!(:locked_discussion) { create(:discussion, :locked, site: site, user: user) }

    describe ".pinned_first" do
      it "returns pinned discussions first, then by last_post_at" do
        result = Discussion.pinned_first
        expect(result.first).to eq(pinned_discussion)
      end
    end

    describe ".recent_activity" do
      it "orders by last_post_at desc" do
        result = Discussion.recent_activity.where.not(last_post_at: nil)
        expect(result.first).to eq(pinned_discussion)
        expect(result.second).to eq(regular_discussion)
      end
    end

    describe ".publicly_visible" do
      it "returns only public discussions" do
        result = Discussion.publicly_visible
        expect(result).to include(pinned_discussion, regular_discussion, locked_discussion)
        expect(result).not_to include(subscribers_only_discussion)
      end
    end

    describe ".unlocked" do
      it "returns only unlocked discussions" do
        result = Discussion.unlocked
        expect(result).to include(pinned_discussion, regular_discussion, subscribers_only_discussion)
        expect(result).not_to include(locked_discussion)
      end
    end
  end

  describe "instance methods" do
    describe "#locked?" do
      it "returns true when locked_at is present" do
        discussion = build(:discussion, :locked)
        expect(discussion.locked?).to be true
      end

      it "returns false when locked_at is nil" do
        discussion = build(:discussion, locked_at: nil)
        expect(discussion.locked?).to be false
      end
    end

    describe "#lock!" do
      let(:discussion) { create(:discussion, site: site, user: user) }
      let(:admin) { create(:user, admin: true) }

      it "sets locked_at to current time" do
        freeze_time do
          discussion.lock!(admin)
          expect(discussion.reload.locked_at).to eq(Time.current)
        end
      end

      it "sets locked_by to the user" do
        discussion.lock!(admin)
        expect(discussion.reload.locked_by).to eq(admin)
      end
    end

    describe "#unlock!" do
      let(:admin) { create(:user, admin: true) }
      let(:discussion) { create(:discussion, :locked, site: site, user: user, locked_by: admin) }

      it "clears locked_at" do
        discussion.unlock!
        expect(discussion.reload.locked_at).to be_nil
      end

      it "clears locked_by" do
        discussion.unlock!
        expect(discussion.reload.locked_by).to be_nil
      end
    end

    describe "#pin!" do
      let(:discussion) { create(:discussion, site: site, user: user) }

      it "sets pinned to true" do
        discussion.pin!
        expect(discussion.reload.pinned).to be true
      end

      it "sets pinned_at to current time" do
        freeze_time do
          discussion.pin!
          expect(discussion.reload.pinned_at).to eq(Time.current)
        end
      end
    end

    describe "#unpin!" do
      let(:discussion) { create(:discussion, :pinned, site: site, user: user) }

      it "sets pinned to false" do
        discussion.unpin!
        expect(discussion.reload.pinned).to be false
      end

      it "clears pinned_at" do
        discussion.unpin!
        expect(discussion.reload.pinned_at).to be_nil
      end
    end

    describe "#touch_last_post!" do
      let(:discussion) { create(:discussion, site: site, user: user, last_post_at: 1.day.ago) }

      it "updates last_post_at to current time" do
        freeze_time do
          discussion.touch_last_post!
          expect(discussion.reload.last_post_at).to eq(Time.current)
        end
      end
    end
  end

  describe "site scoping" do
    let(:other_tenant) { create(:tenant) }
    let(:other_site) { create(:site, tenant: other_tenant) }

    it "scopes queries to current site" do
      discussion1 = create(:discussion, site: site, user: user)

      Current.site = other_site
      discussion2 = create(:discussion, site: other_site, user: create(:user))

      Current.site = site
      expect(Discussion.all).to include(discussion1)
      expect(Discussion.all).not_to include(discussion2)
    end

    it "prevents accessing discussions from other sites" do
      discussion = create(:discussion, site: site, user: user)

      Current.site = other_site
      expect {
        Discussion.find(discussion.id)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "cascade deletion" do
    let(:discussion) { create(:discussion, site: site, user: user) }
    let!(:posts) { create_list(:discussion_post, 3, discussion: discussion, site: site, user: create(:user)) }

    it "destroys posts when discussion is destroyed" do
      expect {
        discussion.destroy
      }.to change(DiscussionPost, :count).by(-3)
    end
  end

  describe "factory" do
    it "creates a valid discussion" do
      discussion = build(:discussion)
      expect(discussion).to be_valid
    end

    it "supports subscribers_only trait" do
      discussion = build(:discussion, :subscribers_only)
      expect(discussion.visibility_subscribers_only?).to be true
    end

    it "supports pinned trait" do
      discussion = build(:discussion, :pinned)
      expect(discussion.pinned?).to be true
      expect(discussion.pinned_at).to be_present
    end

    it "supports locked trait" do
      discussion = build(:discussion, :locked)
      expect(discussion.locked?).to be true
      expect(discussion.locked_by).to be_present
    end

    it "supports with_posts trait" do
      discussion = create(:discussion, :with_posts, site: site, user: user)
      expect(discussion.posts.count).to eq(3)
    end
  end
end
