# frozen_string_literal: true

# == Schema Information
#
# Table name: live_streams
#
#  id                 :bigint           not null, primary key
#  description        :text
#  ended_at           :datetime
#  peak_viewers       :integer          default(0), not null
#  scheduled_at       :datetime         not null
#  started_at         :datetime
#  status             :integer          default("scheduled"), not null
#  stream_key         :string
#  title              :string           not null
#  viewer_count       :integer          default(0), not null
#  visibility         :integer          default("public_access"), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  discussion_id      :bigint
#  mux_asset_id       :string
#  mux_playback_id    :string
#  mux_stream_id      :string
#  replay_playback_id :string
#  site_id            :bigint           not null
#  user_id            :bigint           not null
#
# Indexes
#
#  index_live_streams_on_discussion_id             (discussion_id)
#  index_live_streams_on_mux_stream_id             (mux_stream_id) UNIQUE
#  index_live_streams_on_site_id                   (site_id)
#  index_live_streams_on_site_id_and_scheduled_at  (site_id,scheduled_at)
#  index_live_streams_on_site_id_and_status        (site_id,status)
#  index_live_streams_on_user_id                   (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (discussion_id => discussions.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (user_id => users.id)
#
require "rails_helper"

RSpec.describe LiveStream, type: :model do
  let(:tenant) { create(:tenant) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:user) { create(:user) }

  before do
    Current.site = site
  end

  describe "associations" do
    it { should belong_to(:user) }
    it { should belong_to(:site) }
    it { should belong_to(:discussion).optional }
    it { should have_many(:viewers).class_name("LiveStreamViewer").dependent(:destroy) }
  end

  describe "validations" do
    it { should validate_presence_of(:title) }
    it { should validate_length_of(:title).is_at_most(LiveStream::TITLE_MAX_LENGTH) }
    it { should validate_length_of(:description).is_at_most(LiveStream::DESCRIPTION_MAX_LENGTH) }
    it { should validate_presence_of(:scheduled_at) }
    it { should validate_presence_of(:status) }
    it { should validate_presence_of(:visibility) }

    context "title length" do
      it "allows title up to max length" do
        live_stream = build(:live_stream, site: site, user: user, title: "a" * LiveStream::TITLE_MAX_LENGTH)
        expect(live_stream).to be_valid
      end

      it "rejects title exceeding max length" do
        live_stream = build(:live_stream, site: site, user: user, title: "a" * (LiveStream::TITLE_MAX_LENGTH + 1))
        expect(live_stream).not_to be_valid
        expect(live_stream.errors[:title]).to be_present
      end
    end

    context "description length" do
      it "allows blank description" do
        live_stream = build(:live_stream, site: site, user: user, description: nil)
        expect(live_stream).to be_valid
      end

      it "allows description up to max length" do
        live_stream = build(:live_stream, site: site, user: user, description: "a" * LiveStream::DESCRIPTION_MAX_LENGTH)
        expect(live_stream).to be_valid
      end

      it "rejects description exceeding max length" do
        live_stream = build(:live_stream, site: site, user: user, description: "a" * (LiveStream::DESCRIPTION_MAX_LENGTH + 1))
        expect(live_stream).not_to be_valid
        expect(live_stream.errors[:description]).to be_present
      end
    end
  end

  describe "enums" do
    it "defines status enum" do
      expect(LiveStream.statuses).to eq({
        "scheduled" => 0,
        "live" => 1,
        "ended" => 2,
        "archived" => 3
      })
    end

    it "defines visibility enum" do
      expect(LiveStream.visibilities).to eq({
        "public_access" => 0,
        "subscribers_only" => 1
      })
    end

    it "uses status prefix for enum methods" do
      live_stream = build(:live_stream, status: :scheduled)
      expect(live_stream.status_scheduled?).to be true
      expect(live_stream.status_live?).to be false
    end

    it "uses visibility prefix for enum methods" do
      live_stream = build(:live_stream, visibility: :public_access)
      expect(live_stream.visibility_public_access?).to be true
      expect(live_stream.visibility_subscribers_only?).to be false
    end
  end

  describe "scopes" do
    let!(:scheduled_stream) { create(:live_stream, :scheduled, site: site, user: user, scheduled_at: 1.hour.from_now) }
    let!(:live_stream) { create(:live_stream, :live, site: site, user: user) }
    let!(:ended_stream) { create(:live_stream, :ended, site: site, user: user) }
    let!(:archived_stream) { create(:live_stream, :archived, site: site, user: user) }
    let!(:subscribers_only_stream) { create(:live_stream, :subscribers_only, site: site, user: user) }

    describe ".upcoming" do
      it "returns only scheduled streams in the future" do
        result = LiveStream.upcoming
        expect(result).to include(scheduled_stream)
        expect(result).not_to include(live_stream, ended_stream, archived_stream)
      end

      it "orders by scheduled_at ascending" do
        future_stream = create(:live_stream, :scheduled, site: site, user: user, scheduled_at: 2.hours.from_now)
        result = LiveStream.upcoming.where(visibility: :public_access)
        expect(result.first).to eq(scheduled_stream)
        expect(result.second).to eq(future_stream)
      end
    end

    describe ".live_now" do
      it "returns only live streams" do
        result = LiveStream.live_now
        expect(result).to include(live_stream)
        expect(result).not_to include(scheduled_stream, ended_stream, archived_stream)
      end
    end

    describe ".past" do
      it "returns ended and archived streams" do
        result = LiveStream.past
        expect(result).to include(ended_stream, archived_stream)
        expect(result).not_to include(scheduled_stream, live_stream)
      end
    end

    describe ".publicly_visible" do
      it "returns only public streams" do
        result = LiveStream.publicly_visible
        expect(result).to include(scheduled_stream, live_stream, ended_stream, archived_stream)
        expect(result).not_to include(subscribers_only_stream)
      end
    end
  end

  describe "instance methods" do
    describe "#live?" do
      it "returns true when status is live" do
        live_stream = build(:live_stream, :live)
        expect(live_stream.live?).to be true
      end

      it "returns false when status is not live" do
        live_stream = build(:live_stream, :scheduled)
        expect(live_stream.live?).to be false
      end
    end

    describe "#can_start?" do
      it "returns true when status is scheduled" do
        live_stream = build(:live_stream, :scheduled)
        expect(live_stream.can_start?).to be true
      end

      it "returns false when status is not scheduled" do
        live_stream = build(:live_stream, :live)
        expect(live_stream.can_start?).to be false
      end
    end

    describe "#can_end?" do
      it "returns true when status is live" do
        live_stream = build(:live_stream, :live)
        expect(live_stream.can_end?).to be true
      end

      it "returns false when status is not live" do
        live_stream = build(:live_stream, :scheduled)
        expect(live_stream.can_end?).to be false
      end
    end

    describe "#start!" do
      let(:live_stream) { create(:live_stream, :scheduled, site: site, user: user) }

      it "updates status to live" do
        live_stream.start!
        expect(live_stream.reload.status_live?).to be true
      end

      it "sets started_at to current time" do
        freeze_time do
          live_stream.start!
          expect(live_stream.reload.started_at).to eq(Time.current)
        end
      end

      it "returns false if stream cannot start" do
        live_stream.update!(status: :live)
        expect(live_stream.start!).to be false
      end
    end

    describe "#end!" do
      let(:live_stream) { create(:live_stream, :live, site: site, user: user) }

      it "updates status to ended" do
        live_stream.end!
        expect(live_stream.reload.status_ended?).to be true
      end

      it "sets ended_at to current time" do
        freeze_time do
          live_stream.end!
          expect(live_stream.reload.ended_at).to eq(Time.current)
        end
      end

      it "returns false if stream cannot end" do
        live_stream.update!(status: :scheduled)
        expect(live_stream.end!).to be false
      end
    end

    describe "#archive!" do
      let(:live_stream) { create(:live_stream, :ended, site: site, user: user) }

      it "updates status to archived" do
        live_stream.archive!
        expect(live_stream.reload.status_archived?).to be true
      end

      it "returns false if stream is not ended" do
        live_stream.update!(status: :live)
        expect(live_stream.archive!).to be false
      end
    end

    describe "#replay_available?" do
      it "returns true when ended and replay_playback_id is present" do
        live_stream = build(:live_stream, :with_replay)
        expect(live_stream.replay_available?).to be true
      end

      it "returns false when not ended" do
        live_stream = build(:live_stream, :live, replay_playback_id: "test")
        expect(live_stream.replay_available?).to be false
      end

      it "returns false when replay_playback_id is blank" do
        live_stream = build(:live_stream, :ended, replay_playback_id: nil)
        expect(live_stream.replay_available?).to be false
      end
    end

    describe "#replay_url" do
      it "returns Mux HLS URL when replay is available" do
        live_stream = build(:live_stream, :with_replay)
        expect(live_stream.replay_url).to eq("https://stream.mux.com/#{live_stream.replay_playback_id}.m3u8")
      end

      it "returns nil when replay is not available" do
        live_stream = build(:live_stream, :scheduled)
        expect(live_stream.replay_url).to be_nil
      end
    end

    describe "#playback_url" do
      it "returns Mux HLS URL when mux_playback_id is present" do
        live_stream = build(:live_stream, :with_mux)
        expect(live_stream.playback_url).to eq("https://stream.mux.com/#{live_stream.mux_playback_id}.m3u8")
      end

      it "returns nil when mux_playback_id is blank" do
        live_stream = build(:live_stream, mux_playback_id: nil)
        expect(live_stream.playback_url).to be_nil
      end
    end

    describe "#update_peak_viewers!" do
      let(:live_stream) { create(:live_stream, :live, site: site, user: user, peak_viewers: 5) }

      it "updates peak_viewers when current count is higher" do
        create_list(:live_stream_viewer, 10, live_stream: live_stream, site: site, left_at: nil)
        live_stream.update_peak_viewers!
        expect(live_stream.reload.peak_viewers).to eq(10)
      end

      it "does not update peak_viewers when current count is lower" do
        create_list(:live_stream_viewer, 3, live_stream: live_stream, site: site, left_at: nil)
        live_stream.update_peak_viewers!
        expect(live_stream.reload.peak_viewers).to eq(5)
      end
    end

    describe "#refresh_viewer_count!" do
      let(:live_stream) { create(:live_stream, :live, site: site, user: user, viewer_count: 0) }

      it "updates viewer_count to active viewer count" do
        create_list(:live_stream_viewer, 5, live_stream: live_stream, site: site, left_at: nil)
        create_list(:live_stream_viewer, 3, :completed, live_stream: live_stream, site: site)
        live_stream.refresh_viewer_count!
        expect(live_stream.reload.viewer_count).to eq(5)
      end
    end
  end

  describe "site scoping" do
    let(:other_tenant) { create(:tenant) }
    let(:other_site) { create(:site, tenant: other_tenant) }

    it "scopes queries to current site" do
      live_stream1 = create(:live_stream, site: site, user: user)

      Current.site = other_site
      live_stream2 = create(:live_stream, site: other_site, user: create(:user))

      Current.site = site
      expect(LiveStream.all).to include(live_stream1)
      expect(LiveStream.all).not_to include(live_stream2)
    end

    it "prevents accessing live streams from other sites" do
      live_stream = create(:live_stream, site: site, user: user)

      Current.site = other_site
      expect {
        LiveStream.find(live_stream.id)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "cascade deletion" do
    let(:live_stream) { create(:live_stream, site: site, user: user) }
    let!(:viewers) { create_list(:live_stream_viewer, 3, live_stream: live_stream, site: site) }

    it "destroys viewers when live stream is destroyed" do
      expect {
        live_stream.destroy
      }.to change(LiveStreamViewer, :count).by(-3)
    end
  end

  describe "factory" do
    it "creates a valid live stream" do
      live_stream = build(:live_stream)
      expect(live_stream).to be_valid
    end

    it "supports scheduled trait" do
      live_stream = build(:live_stream, :scheduled)
      expect(live_stream.status_scheduled?).to be true
      expect(live_stream.started_at).to be_nil
    end

    it "supports live trait" do
      live_stream = build(:live_stream, :live)
      expect(live_stream.status_live?).to be true
      expect(live_stream.started_at).to be_present
    end

    it "supports ended trait" do
      live_stream = build(:live_stream, :ended)
      expect(live_stream.status_ended?).to be true
      expect(live_stream.ended_at).to be_present
    end

    it "supports with_mux trait" do
      live_stream = build(:live_stream, :with_mux)
      expect(live_stream.mux_stream_id).to be_present
      expect(live_stream.mux_playback_id).to be_present
      expect(live_stream.stream_key).to be_present
    end

    it "supports with_replay trait" do
      live_stream = build(:live_stream, :with_replay)
      expect(live_stream.replay_available?).to be true
    end

    it "supports subscribers_only trait" do
      live_stream = build(:live_stream, :subscribers_only)
      expect(live_stream.visibility_subscribers_only?).to be true
    end

    it "supports with_discussion trait" do
      live_stream = create(:live_stream, :with_discussion, site: site, user: user)
      expect(live_stream.discussion).to be_present
    end
  end
end
