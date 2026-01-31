# frozen_string_literal: true

# == Schema Information
#
# Table name: live_stream_viewers
#
#  id               :bigint           not null, primary key
#  duration_seconds :integer
#  joined_at        :datetime         not null
#  left_at          :datetime
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  live_stream_id   :bigint           not null
#  session_id       :string
#  site_id          :bigint           not null
#  user_id          :bigint
#
# Indexes
#
#  index_live_stream_viewers_on_live_stream_id      (live_stream_id)
#  index_live_stream_viewers_on_site_id             (site_id)
#  index_live_stream_viewers_on_stream_and_session  (live_stream_id,session_id) UNIQUE WHERE (session_id IS NOT NULL)
#  index_live_stream_viewers_on_stream_and_user     (live_stream_id,user_id) UNIQUE WHERE (user_id IS NOT NULL)
#  index_live_stream_viewers_on_user_id             (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (live_stream_id => live_streams.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (user_id => users.id)
#
require "rails_helper"

RSpec.describe LiveStreamViewer, type: :model do
  let(:tenant) { create(:tenant) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:user) { create(:user) }
  let(:live_stream) { create(:live_stream, :live, site: site, user: user) }

  before do
    Current.site = site
  end

  describe "associations" do
    it { should belong_to(:live_stream) }
    it { should belong_to(:site) }
    it { should belong_to(:user).optional }
  end

  describe "validations" do
    it { should validate_presence_of(:joined_at) }

    context "user or session validation" do
      it "is valid with a user" do
        viewer = build(:live_stream_viewer, live_stream: live_stream, site: site, user: user, session_id: nil)
        expect(viewer).to be_valid
      end

      it "is valid with a session_id" do
        viewer = build(:live_stream_viewer, :anonymous, live_stream: live_stream, site: site)
        expect(viewer).to be_valid
      end

      it "is invalid without user or session_id" do
        viewer = build(:live_stream_viewer, live_stream: live_stream, site: site, user: nil, session_id: nil)
        expect(viewer).not_to be_valid
        expect(viewer.errors[:base]).to include("must have either a user or a session_id")
      end
    end
  end

  describe "scopes" do
    let!(:active_viewer) { create(:live_stream_viewer, :active, live_stream: live_stream, site: site) }
    let!(:completed_viewer) { create(:live_stream_viewer, :completed, live_stream: live_stream, site: site) }

    describe ".active" do
      it "returns only viewers with no left_at" do
        result = LiveStreamViewer.active
        expect(result).to include(active_viewer)
        expect(result).not_to include(completed_viewer)
      end
    end

    describe ".completed" do
      it "returns only viewers with left_at set" do
        result = LiveStreamViewer.completed
        expect(result).to include(completed_viewer)
        expect(result).not_to include(active_viewer)
      end
    end
  end

  describe "instance methods" do
    describe "#active?" do
      it "returns true when left_at is nil" do
        viewer = build(:live_stream_viewer, :active)
        expect(viewer.active?).to be true
      end

      it "returns false when left_at is present" do
        viewer = build(:live_stream_viewer, :completed)
        expect(viewer.active?).to be false
      end
    end

    describe "#leave!" do
      let(:viewer) { create(:live_stream_viewer, live_stream: live_stream, site: site, joined_at: 30.minutes.ago, left_at: nil) }

      it "sets left_at to current time" do
        freeze_time do
          viewer.leave!
          expect(viewer.reload.left_at).to eq(Time.current)
        end
      end

      it "calculates and sets duration_seconds" do
        freeze_time do
          viewer.leave!
          expect(viewer.reload.duration_seconds).to eq(1800) # 30 minutes in seconds
        end
      end

      it "does nothing if already left" do
        viewer.update!(left_at: 10.minutes.ago, duration_seconds: 1200)
        original_left_at = viewer.left_at

        viewer.leave!
        expect(viewer.reload.left_at).to eq(original_left_at)
      end
    end

    describe "#calculate_duration" do
      it "calculates duration from joined_at to left_at" do
        viewer = build(:live_stream_viewer, joined_at: 1.hour.ago, left_at: 30.minutes.ago)
        expect(viewer.calculate_duration).to eq(1800) # 30 minutes
      end

      it "calculates duration to current time when left_at is nil" do
        freeze_time do
          viewer = build(:live_stream_viewer, joined_at: 1.hour.ago, left_at: nil)
          expect(viewer.calculate_duration).to eq(3600) # 1 hour
        end
      end

      it "returns nil when joined_at is nil" do
        viewer = build(:live_stream_viewer)
        viewer.joined_at = nil
        expect(viewer.calculate_duration).to be_nil
      end
    end
  end

  describe "site scoping" do
    let(:other_tenant) { create(:tenant) }
    let(:other_site) { create(:site, tenant: other_tenant) }

    it "scopes queries to current site" do
      viewer1 = create(:live_stream_viewer, live_stream: live_stream, site: site)

      Current.site = other_site
      other_live_stream = create(:live_stream, site: other_site, user: create(:user))
      viewer2 = create(:live_stream_viewer, live_stream: other_live_stream, site: other_site)

      Current.site = site
      expect(LiveStreamViewer.all).to include(viewer1)
      expect(LiveStreamViewer.all).not_to include(viewer2)
    end
  end

  describe "factory" do
    it "creates a valid live stream viewer" do
      viewer = build(:live_stream_viewer, live_stream: live_stream, site: site, user: user)
      expect(viewer).to be_valid
    end

    it "supports active trait" do
      viewer = build(:live_stream_viewer, :active)
      expect(viewer.active?).to be true
    end

    it "supports completed trait" do
      viewer = build(:live_stream_viewer, :completed)
      expect(viewer.active?).to be false
      expect(viewer.duration_seconds).to be_present
    end

    it "supports anonymous trait" do
      viewer = build(:live_stream_viewer, :anonymous)
      expect(viewer.user).to be_nil
      expect(viewer.session_id).to be_present
    end
  end
end
