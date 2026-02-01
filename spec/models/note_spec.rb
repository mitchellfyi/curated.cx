# frozen_string_literal: true

# == Schema Information
#
# Table name: notes
#
#  id             :bigint           not null, primary key
#  body           :text             not null
#  comments_count :integer          default(0), not null
#  hidden_at      :datetime
#  link_preview   :jsonb
#  published_at   :datetime
#  reposts_count  :integer          default(0), not null
#  upvotes_count  :integer          default(0), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  hidden_by_id   :bigint
#  repost_of_id   :bigint
#  site_id        :bigint           not null
#  user_id        :bigint           not null
#
require "rails_helper"

RSpec.describe Note, type: :model do
  let(:tenant) { create(:tenant) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:user) { create(:user) }

  before do
    Current.site = site
  end

  describe "associations" do
    it { should belong_to(:user) }
    it { should belong_to(:site) }
    it { should belong_to(:hidden_by).class_name("User").optional }
    it { should belong_to(:repost_of).class_name("Note").optional }
    it { should have_many(:reposts).class_name("Note").with_foreign_key(:repost_of_id).dependent(:nullify) }
    it { should have_many(:votes).dependent(:destroy) }
    it { should have_many(:comments).dependent(:destroy) }
    it { should have_many(:bookmarks).dependent(:destroy) }
    it { should have_many(:flags).dependent(:destroy) }
  end

  describe "validations" do
    it { should validate_presence_of(:body) }
    it { should validate_length_of(:body).is_at_most(Note::BODY_MAX_LENGTH) }

    context "body length" do
      it "allows body up to max length (500 chars)" do
        note = build(:note, site: site, user: user, body: "a" * Note::BODY_MAX_LENGTH)
        expect(note).to be_valid
      end

      it "rejects body exceeding max length" do
        note = build(:note, site: site, user: user, body: "a" * (Note::BODY_MAX_LENGTH + 1))
        expect(note).not_to be_valid
        expect(note.errors[:body]).to be_present
      end
    end

    context "repost validation" do
      it "allows reposting a regular note" do
        original = create(:note, :published, site: site, user: user)
        repost = build(:note, site: site, user: create(:user), repost_of: original)
        expect(repost).to be_valid
      end

      it "rejects reposting a repost" do
        original = create(:note, :published, site: site, user: user)
        first_repost = create(:note, :published, site: site, user: create(:user), repost_of: original)
        second_repost = build(:note, site: site, user: create(:user), repost_of: first_repost)

        expect(second_repost).not_to be_valid
        expect(second_repost.errors[:repost_of]).to include("cannot be a repost of another repost")
      end
    end
  end

  describe "scopes" do
    let!(:published_note) { create(:note, :published, site: site, user: user) }
    let!(:draft_note) { create(:note, :draft, site: site, user: create(:user)) }
    let!(:hidden_note) { create(:note, :published, :hidden, site: site, user: create(:user)) }

    describe ".published" do
      it "returns only published notes" do
        expect(Note.published).to include(published_note, hidden_note)
        expect(Note.published).not_to include(draft_note)
      end
    end

    describe ".drafts" do
      it "returns only draft notes" do
        expect(Note.drafts).to include(draft_note)
        expect(Note.drafts).not_to include(published_note)
      end
    end

    describe ".not_hidden" do
      it "returns only visible notes" do
        expect(Note.not_hidden).to include(published_note, draft_note)
        expect(Note.not_hidden).not_to include(hidden_note)
      end
    end

    describe ".for_feed" do
      it "returns published and visible notes" do
        expect(Note.for_feed).to include(published_note)
        expect(Note.for_feed).not_to include(draft_note, hidden_note)
      end

      it "orders by published_at desc" do
        older_note = create(:note, :published, site: site, user: user, published_at: 1.day.ago)
        newer_note = create(:note, :published, site: site, user: user, published_at: 1.hour.ago)

        feed = Note.for_feed
        expect(feed.index(newer_note)).to be < feed.index(older_note)
      end
    end

    describe ".by_user" do
      it "returns notes by the specified user" do
        expect(Note.by_user(user)).to include(published_note)
        expect(Note.by_user(user)).not_to include(draft_note)
      end
    end

    describe ".original" do
      it "returns only original notes (not reposts)" do
        repost = create(:note, :published, site: site, user: create(:user), repost_of: published_note)

        expect(Note.original).to include(published_note)
        expect(Note.original).not_to include(repost)
      end
    end

    describe ".reposts_only" do
      it "returns only reposts" do
        repost = create(:note, :published, site: site, user: create(:user), repost_of: published_note)

        expect(Note.reposts_only).to include(repost)
        expect(Note.reposts_only).not_to include(published_note)
      end
    end

    describe ".recent" do
      it "orders by created_at desc" do
        old_note = create(:note, site: site, user: user, created_at: 1.day.ago)
        new_note = create(:note, site: site, user: user, created_at: 1.hour.ago)

        recent_notes = Note.recent
        expect(recent_notes.index(new_note)).to be < recent_notes.index(old_note)
      end
    end

    describe ".published_since" do
      it "returns notes published since the given time" do
        recent = create(:note, :published, site: site, user: user, published_at: 1.day.ago)
        old = create(:note, :published, site: site, user: user, published_at: 10.days.ago)

        expect(Note.published_since(5.days.ago)).to include(recent)
        expect(Note.published_since(5.days.ago)).not_to include(old)
      end
    end
  end

  describe "instance methods" do
    describe "#published?" do
      it "returns true when published_at is present" do
        note = build(:note, :published)
        expect(note.published?).to be true
      end

      it "returns false when published_at is nil" do
        note = build(:note, :draft)
        expect(note.published?).to be false
      end
    end

    describe "#draft?" do
      it "returns true when published_at is nil" do
        note = build(:note, :draft)
        expect(note.draft?).to be true
      end

      it "returns false when published_at is present" do
        note = build(:note, :published)
        expect(note.draft?).to be false
      end
    end

    describe "#hidden?" do
      it "returns true when hidden_at is present" do
        note = build(:note, :hidden)
        expect(note.hidden?).to be true
      end

      it "returns false when hidden_at is nil" do
        note = build(:note, hidden_at: nil)
        expect(note.hidden?).to be false
      end
    end

    describe "#repost?" do
      it "returns true when repost_of_id is present" do
        original = create(:note, :published, site: site, user: user)
        repost = build(:note, repost_of: original)
        expect(repost.repost?).to be true
      end

      it "returns false when repost_of_id is nil" do
        note = build(:note, repost_of: nil)
        expect(note.repost?).to be false
      end
    end

    describe "#original_note" do
      it "returns the original note for a repost" do
        original = create(:note, :published, site: site, user: user)
        repost = build(:note, repost_of: original)
        expect(repost.original_note).to eq(original)
      end

      it "returns self for an original note" do
        note = build(:note, site: site, user: user)
        expect(note.original_note).to eq(note)
      end
    end

    describe "#link_preview" do
      it "returns empty hash when nil" do
        note = build(:note, link_preview: nil)
        expect(note.link_preview).to eq({})
      end

      it "returns the stored preview data" do
        preview_data = { "url" => "https://example.com", "title" => "Example" }
        note = build(:note, link_preview: preview_data)
        expect(note.link_preview).to eq(preview_data)
      end
    end

    describe "#has_link_preview?" do
      it "returns true when link_preview has a url" do
        note = build(:note, :with_link_preview)
        expect(note.has_link_preview?).to be true
      end

      it "returns false when link_preview is empty" do
        note = build(:note, link_preview: {})
        expect(note.has_link_preview?).to be false
      end

      it "returns false when link_preview has no url" do
        note = build(:note, link_preview: { "title" => "Test" })
        expect(note.has_link_preview?).to be false
      end
    end

    describe "#publish!" do
      it "sets published_at to current time" do
        note = create(:note, :draft, site: site, user: user)
        freeze_time do
          note.publish!
          expect(note.reload.published_at).to eq(Time.current)
        end
      end

      it "does not change published_at if already published" do
        original_time = 1.day.ago
        note = create(:note, site: site, user: user, published_at: original_time)

        note.publish!
        expect(note.reload.published_at).to be_within(1.second).of(original_time)
      end
    end

    describe "#unpublish!" do
      it "sets published_at to nil" do
        note = create(:note, :published, site: site, user: user)
        note.unpublish!
        expect(note.reload.published_at).to be_nil
      end

      it "does nothing if already a draft" do
        note = create(:note, :draft, site: site, user: user)
        expect { note.unpublish! }.not_to change { note.reload.published_at }
      end
    end

    describe "#hide!" do
      it "sets hidden_at and hidden_by" do
        note = create(:note, :published, site: site, user: user)
        admin = create(:user)

        freeze_time do
          note.hide!(admin)
          note.reload
          expect(note.hidden_at).to eq(Time.current)
          expect(note.hidden_by).to eq(admin)
        end
      end
    end

    describe "#unhide!" do
      it "clears hidden_at and hidden_by" do
        admin = create(:user)
        note = create(:note, :published, :hidden, site: site, user: user)

        note.unhide!
        note.reload
        expect(note.hidden_at).to be_nil
        expect(note.hidden_by).to be_nil
      end
    end

    describe "#extract_first_url" do
      it "extracts URL from body text" do
        note = build(:note, body: "Check this out: https://example.com/article and more text")
        expect(note.extract_first_url).to eq("https://example.com/article")
      end

      it "extracts HTTP URL" do
        note = build(:note, body: "Check http://example.com/page out")
        expect(note.extract_first_url).to eq("http://example.com/page")
      end

      it "returns nil when no URL present" do
        note = build(:note, body: "Just some text without links")
        expect(note.extract_first_url).to be_nil
      end

      it "returns nil for blank body" do
        note = build(:note)
        note.body = ""
        expect(note.extract_first_url).to be_nil
      end
    end
  end

  describe "site scoping" do
    let(:other_tenant) { create(:tenant) }
    let(:other_site) { create(:site, tenant: other_tenant) }

    it "scopes queries to current site" do
      note1 = create(:note, site: site, user: user)

      Current.site = other_site
      note2 = create(:note, site: other_site, user: create(:user))

      Current.site = site
      expect(Note.all).to include(note1)
      expect(Note.all).not_to include(note2)
    end

    it "prevents accessing notes from other sites" do
      note = create(:note, site: site, user: user)

      Current.site = other_site
      expect {
        Note.find(note.id)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "counter caches" do
    describe "upvotes_count" do
      it "increments when a vote is created" do
        note = create(:note, :published, site: site, user: user)
        voter = create(:user)

        expect {
          create(:vote, votable: note, user: voter, site: site)
        }.to change { note.reload.upvotes_count }.by(1)
      end

      it "decrements when a vote is destroyed" do
        note = create(:note, :published, site: site, user: user)
        voter = create(:user)
        vote = create(:vote, votable: note, user: voter, site: site)
        note.reload

        expect {
          vote.destroy
        }.to change { note.reload.upvotes_count }.by(-1)
      end
    end

    describe "comments_count" do
      it "increments when a comment is created" do
        note = create(:note, :published, site: site, user: user)
        commenter = create(:user)

        expect {
          create(:comment, commentable: note, user: commenter, site: site)
        }.to change { note.reload.comments_count }.by(1)
      end

      it "decrements when a comment is destroyed" do
        note = create(:note, :published, site: site, user: user)
        commenter = create(:user)
        comment = create(:comment, commentable: note, user: commenter, site: site)
        note.reload

        expect {
          comment.destroy
        }.to change { note.reload.comments_count }.by(-1)
      end
    end

    describe "reposts_count" do
      it "increments when a repost is created" do
        original = create(:note, :published, site: site, user: user)

        expect {
          create(:note, :published, site: site, user: create(:user), repost_of: original)
        }.to change { original.reload.reposts_count }.by(1)
      end

      it "does not decrement when repost is destroyed (dependent: :nullify)" do
        original = create(:note, :published, site: site, user: user)
        repost = create(:note, :published, site: site, user: create(:user), repost_of: original)
        original.reload

        # With dependent: :nullify, the repost_of_id is set to nil, not destroyed
        # Counter cache decrement happens only on repost_of_id change
        expect {
          repost.update!(repost_of: nil)
        }.to change { original.reload.reposts_count }.by(-1)
      end
    end
  end

  describe "callbacks" do
    describe "link preview extraction" do
      it "enqueues ExtractNoteLinkPreviewJob when note contains a URL" do
        expect {
          create(:note, :with_link, site: site, user: user)
        }.to have_enqueued_job(ExtractNoteLinkPreviewJob)
      end

      it "does not enqueue job when note has no URL" do
        expect {
          create(:note, site: site, user: user, body: "No links here")
        }.not_to have_enqueued_job(ExtractNoteLinkPreviewJob)
      end
    end
  end

  describe "factory" do
    it "creates a valid note" do
      note = build(:note, site: site, user: user)
      expect(note).to be_valid
    end

    it "supports published trait" do
      note = build(:note, :published)
      expect(note.published?).to be true
    end

    it "supports draft trait" do
      note = build(:note, :draft)
      expect(note.draft?).to be true
    end

    it "supports hidden trait" do
      note = build(:note, :hidden)
      expect(note.hidden?).to be true
    end

    it "supports with_link trait" do
      note = build(:note, :with_link)
      expect(note.body).to include("https://")
    end

    it "supports with_link_preview trait" do
      note = build(:note, :with_link_preview)
      expect(note.has_link_preview?).to be true
    end

    it "supports repost trait" do
      note = create(:note, :repost, :published, site: site, user: user)
      expect(note.repost?).to be true
      expect(note.repost_of).to be_present
    end
  end
end
