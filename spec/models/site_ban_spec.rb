# frozen_string_literal: true

# == Schema Information
#
# Table name: site_bans
#
#  id           :bigint           not null, primary key
#  banned_at    :datetime         not null
#  expires_at   :datetime
#  reason       :text
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  banned_by_id :bigint           not null
#  site_id      :bigint           not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_site_bans_on_banned_by_id      (banned_by_id)
#  index_site_bans_on_site_and_expires  (site_id,expires_at)
#  index_site_bans_on_site_id           (site_id)
#  index_site_bans_on_user_id           (user_id)
#  index_site_bans_uniqueness           (site_id,user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (banned_by_id => users.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (user_id => users.id)
#
require "rails_helper"

RSpec.describe SiteBan, type: :model do
  let(:tenant) { create(:tenant) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:user) { create(:user) }
  let(:admin) { create(:user, admin: true) }

  before do
    Current.site = site
  end

  describe "associations" do
    it { should belong_to(:user) }
    it { should belong_to(:banned_by).class_name("User") }
    it { should belong_to(:site) }
  end

  describe "validations" do
    # Use a built factory instance as subject so associations are populated
    subject { build(:site_ban, site: site, user: user, banned_by: admin) }

    it "auto-sets banned_at if not provided" do
      # The model has before_validation :set_banned_at which auto-fills banned_at
      ban = build(:site_ban, site: site, user: user, banned_by: admin, banned_at: nil)
      ban.valid?
      expect(ban.banned_at).to be_present
    end

    context "uniqueness" do
      it "validates uniqueness of user_id scoped to site" do
        create(:site_ban, site: site, user: user, banned_by: admin)

        duplicate = build(:site_ban, site: site, user: user, banned_by: admin)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:user_id]).to include("is already banned from this site")
      end

      it "allows same user to be banned from different sites" do
        create(:site_ban, site: site, user: user, banned_by: admin)

        other_tenant = create(:tenant)
        other_site = create(:site, tenant: other_tenant)

        Current.site = other_site
        other_ban = build(:site_ban, site: other_site, user: user, banned_by: admin)
        expect(other_ban).to be_valid
      end
    end

    context "cannot ban self" do
      it "prevents users from banning themselves" do
        ban = build(:site_ban, site: site, user: admin, banned_by: admin)
        expect(ban).not_to be_valid
        expect(ban.errors[:user]).to include("cannot ban yourself")
      end
    end
  end

  describe "scopes" do
    describe ".active" do
      it "includes bans with no expiry" do
        permanent = create(:site_ban, :permanent, site: site, user: user, banned_by: admin)
        expect(SiteBan.active).to include(permanent)
      end

      it "includes bans with future expiry" do
        temporary = create(:site_ban, :temporary, site: site, user: user, banned_by: admin)
        expect(SiteBan.active).to include(temporary)
      end

      it "excludes expired bans" do
        expired = create(:site_ban, :expired, site: site, user: user, banned_by: admin)
        expect(SiteBan.active).not_to include(expired)
      end
    end

    describe ".expired" do
      it "includes expired bans" do
        expired = create(:site_ban, :expired, site: site, user: user, banned_by: admin)
        expect(SiteBan.expired).to include(expired)
      end

      it "excludes active bans" do
        permanent = create(:site_ban, :permanent, site: site, user: user, banned_by: admin)
        expect(SiteBan.expired).not_to include(permanent)
      end
    end

    describe ".permanent" do
      it "includes bans with no expiry" do
        permanent = create(:site_ban, :permanent, site: site, user: user, banned_by: admin)
        expect(SiteBan.permanent).to include(permanent)
      end

      it "excludes temporary bans" do
        temporary = create(:site_ban, :temporary, site: site, user: user, banned_by: admin)
        expect(SiteBan.permanent).not_to include(temporary)
      end
    end

    describe ".for_user" do
      it "returns bans for the specified user" do
        ban = create(:site_ban, site: site, user: user, banned_by: admin)
        other_ban = create(:site_ban, site: site, user: create(:user), banned_by: admin)

        expect(SiteBan.for_user(user)).to include(ban)
        expect(SiteBan.for_user(user)).not_to include(other_ban)
      end
    end
  end

  describe "instance methods" do
    describe "#expired?" do
      it "returns false for permanent bans" do
        ban = build(:site_ban, :permanent)
        expect(ban.expired?).to be false
      end

      it "returns false for future expiry" do
        ban = build(:site_ban, expires_at: 1.week.from_now)
        expect(ban.expired?).to be false
      end

      it "returns true for past expiry" do
        ban = build(:site_ban, :expired)
        expect(ban.expired?).to be true
      end
    end

    describe "#active?" do
      it "returns true for permanent bans" do
        ban = build(:site_ban, :permanent)
        expect(ban.active?).to be true
      end

      it "returns true for future expiry" do
        ban = build(:site_ban, expires_at: 1.week.from_now)
        expect(ban.active?).to be true
      end

      it "returns false for past expiry" do
        ban = build(:site_ban, :expired)
        expect(ban.active?).to be false
      end
    end

    describe "#permanent?" do
      it "returns true when expires_at is nil" do
        ban = build(:site_ban, :permanent)
        expect(ban.permanent?).to be true
      end

      it "returns false when expires_at is set" do
        ban = build(:site_ban, :temporary)
        expect(ban.permanent?).to be false
      end
    end
  end

  describe "callbacks" do
    describe "set_banned_at" do
      it "sets banned_at to current time on create if not provided" do
        freeze_time do
          ban = create(:site_ban, site: site, user: user, banned_by: admin, banned_at: nil)
          expect(ban.banned_at).to eq(Time.current)
        end
      end

      it "does not override provided banned_at" do
        specific_time = 2.days.ago
        ban = create(:site_ban, site: site, user: user, banned_by: admin, banned_at: specific_time)
        expect(ban.banned_at).to be_within(1.second).of(specific_time)
      end
    end
  end

  describe "site scoping" do
    let(:other_tenant) { create(:tenant) }
    let(:other_site) { create(:site, tenant: other_tenant) }

    it "scopes queries to current site" do
      ban1 = create(:site_ban, site: site, user: user, banned_by: admin)

      Current.site = other_site
      other_user = create(:user)
      ban2 = create(:site_ban, site: other_site, user: other_user, banned_by: admin)

      Current.site = site
      expect(SiteBan.all).to include(ban1)
      expect(SiteBan.all).not_to include(ban2)
    end

    it "prevents accessing bans from other sites" do
      ban = create(:site_ban, site: site, user: user, banned_by: admin)

      Current.site = other_site
      expect {
        SiteBan.find(ban.id)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "factory" do
    it "creates a valid site_ban" do
      ban = build(:site_ban)
      expect(ban).to be_valid
    end

    it "supports temporary trait" do
      ban = build(:site_ban, :temporary)
      expect(ban.expires_at).to be > Time.current
      expect(ban.permanent?).to be false
    end

    it "supports expired trait" do
      ban = build(:site_ban, :expired)
      expect(ban.expired?).to be true
    end

    it "supports permanent trait" do
      ban = build(:site_ban, :permanent)
      expect(ban.permanent?).to be true
    end
  end
end
