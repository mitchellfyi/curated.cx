# frozen_string_literal: true

require "rails_helper"

RSpec.describe NotePolicy, type: :policy do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, admin: true) }
  let(:tenant) { create(:tenant) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:note_owner) { create(:user) }
  let(:note) { create(:note, :published, site: site, user: note_owner) }

  before do
    allow(Current).to receive(:tenant).and_return(tenant)
    allow(Current).to receive(:site).and_return(site)
  end

  describe "#index?" do
    context "when tenant does not require login" do
      before { allow(tenant).to receive(:requires_login?).and_return(false) }

      it "allows access for any user" do
        policy = described_class.new(user, note)
        expect(policy.index?).to be true
      end

      it "allows access for nil user" do
        policy = described_class.new(nil, note)
        expect(policy.index?).to be true
      end
    end

    context "when tenant requires login" do
      before { allow(tenant).to receive(:requires_login?).and_return(true) }

      it "allows access for logged in user" do
        policy = described_class.new(user, note)
        expect(policy.index?).to be true
      end

      it "denies access for nil user" do
        policy = described_class.new(nil, note)
        expect(policy.index?).to be false
      end
    end
  end

  describe "#show?" do
    context "when note is published and not hidden" do
      let(:published_note) { create(:note, :published, site: site, user: note_owner) }

      context "when tenant does not require login" do
        before { allow(tenant).to receive(:requires_login?).and_return(false) }

        it "allows access for any user" do
          policy = described_class.new(user, published_note)
          expect(policy.show?).to be true
        end

        it "allows access for nil user" do
          policy = described_class.new(nil, published_note)
          expect(policy.show?).to be true
        end
      end

      context "when tenant requires login" do
        before { allow(tenant).to receive(:requires_login?).and_return(true) }

        it "allows access for logged in user" do
          policy = described_class.new(user, published_note)
          expect(policy.show?).to be true
        end

        it "denies access for nil user" do
          policy = described_class.new(nil, published_note)
          expect(policy.show?).to be false
        end
      end
    end

    context "when note is not published (draft)" do
      let(:draft_note) { create(:note, :draft, site: site, user: note_owner) }

      it "denies access for any user" do
        policy = described_class.new(user, draft_note)
        expect(policy.show?).to be false
      end

      it "denies access for admin user" do
        policy = described_class.new(admin_user, draft_note)
        expect(policy.show?).to be false
      end
    end

    context "when note is hidden" do
      let(:hidden_note) { create(:note, :published, :hidden, site: site, user: note_owner) }

      it "denies access for any user" do
        policy = described_class.new(user, hidden_note)
        expect(policy.show?).to be false
      end

      it "denies access for admin user" do
        policy = described_class.new(admin_user, hidden_note)
        expect(policy.show?).to be false
      end
    end

    context "when record is nil" do
      it "denies access" do
        policy = described_class.new(user, nil)
        expect(policy.show?).to be false
      end
    end
  end

  describe "#create?" do
    context "when user is global admin" do
      it "allows access" do
        policy = described_class.new(admin_user, note)
        expect(policy.create?).to be true
      end
    end

    context "when user has editor role" do
      before { user.add_role(:editor, tenant) }

      it "allows access" do
        policy = described_class.new(user, note)
        expect(policy.create?).to be true
      end
    end

    context "when user has tenant admin role" do
      before { user.add_role(:admin, tenant) }

      it "allows access" do
        policy = described_class.new(user, note)
        expect(policy.create?).to be true
      end
    end

    context "when user has owner role" do
      before { user.add_role(:owner, tenant) }

      it "allows access" do
        policy = described_class.new(user, note)
        expect(policy.create?).to be true
      end
    end

    context "when user has viewer role only" do
      before { user.add_role(:viewer, tenant) }

      it "denies access" do
        policy = described_class.new(user, note)
        expect(policy.create?).to be false
      end
    end

    context "when user has no roles" do
      it "denies access" do
        policy = described_class.new(user, note)
        expect(policy.create?).to be false
      end
    end

    context "when user is nil" do
      it "denies access" do
        policy = described_class.new(nil, note)
        expect(policy.create?).to be false
      end
    end
  end

  describe "#update?" do
    context "when user is global admin" do
      it "allows access" do
        policy = described_class.new(admin_user, note)
        expect(policy.update?).to be true
      end
    end

    context "when user has tenant owner role" do
      before { user.add_role(:owner, tenant) }

      it "allows access" do
        policy = described_class.new(user, note)
        expect(policy.update?).to be true
      end
    end

    context "when user has tenant admin role" do
      before { user.add_role(:admin, tenant) }

      it "allows access" do
        policy = described_class.new(user, note)
        expect(policy.update?).to be true
      end
    end

    context "when user is the note owner" do
      let(:my_note) { create(:note, :published, site: site, user: user) }

      it "allows access to own note" do
        policy = described_class.new(user, my_note)
        expect(policy.update?).to be true
      end
    end

    context "when user is not the note owner and has no admin role" do
      it "denies access to others' notes" do
        policy = described_class.new(user, note)
        expect(policy.update?).to be false
      end
    end

    context "when user has editor role only" do
      before { user.add_role(:editor, tenant) }

      it "denies access to others' notes" do
        policy = described_class.new(user, note)
        expect(policy.update?).to be false
      end
    end

    context "when user is nil" do
      it "denies access" do
        policy = described_class.new(nil, note)
        expect(policy.update?).to be false
      end
    end
  end

  describe "#destroy?" do
    context "when user is global admin" do
      it "allows access" do
        policy = described_class.new(admin_user, note)
        expect(policy.destroy?).to be true
      end
    end

    context "when user has tenant owner role" do
      before { user.add_role(:owner, tenant) }

      it "allows access" do
        policy = described_class.new(user, note)
        expect(policy.destroy?).to be true
      end
    end

    context "when user has tenant admin role" do
      before { user.add_role(:admin, tenant) }

      it "allows access" do
        policy = described_class.new(user, note)
        expect(policy.destroy?).to be true
      end
    end

    context "when user is the note owner" do
      let(:my_note) { create(:note, :published, site: site, user: user) }

      it "allows access to own note" do
        policy = described_class.new(user, my_note)
        expect(policy.destroy?).to be true
      end
    end

    context "when user is not the note owner and has no admin role" do
      it "denies access to others' notes" do
        policy = described_class.new(user, note)
        expect(policy.destroy?).to be false
      end
    end

    context "when user has editor role only" do
      before { user.add_role(:editor, tenant) }

      it "denies access to others' notes" do
        policy = described_class.new(user, note)
        expect(policy.destroy?).to be false
      end
    end
  end

  describe "#repost?" do
    context "when user is global admin" do
      it "allows access" do
        policy = described_class.new(admin_user, note)
        expect(policy.repost?).to be true
      end
    end

    context "when user has editor role" do
      before { user.add_role(:editor, tenant) }

      it "allows access" do
        policy = described_class.new(user, note)
        expect(policy.repost?).to be true
      end
    end

    context "when user has no roles" do
      it "denies access" do
        policy = described_class.new(user, note)
        expect(policy.repost?).to be false
      end
    end
  end

  describe "#hide?" do
    context "when user is global admin" do
      it "allows access" do
        policy = described_class.new(admin_user, note)
        expect(policy.hide?).to be true
      end
    end

    context "when user has tenant owner role" do
      before { user.add_role(:owner, tenant) }

      it "allows access" do
        policy = described_class.new(user, note)
        expect(policy.hide?).to be true
      end
    end

    context "when user has tenant admin role" do
      before { user.add_role(:admin, tenant) }

      it "allows access" do
        policy = described_class.new(user, note)
        expect(policy.hide?).to be true
      end
    end

    context "when user has editor role only" do
      before { user.add_role(:editor, tenant) }

      it "denies access" do
        policy = described_class.new(user, note)
        expect(policy.hide?).to be false
      end
    end
  end

  describe "#unhide?" do
    context "when user is global admin" do
      it "allows access" do
        policy = described_class.new(admin_user, note)
        expect(policy.unhide?).to be true
      end
    end

    context "when user has tenant owner role" do
      before { user.add_role(:owner, tenant) }

      it "allows access" do
        policy = described_class.new(user, note)
        expect(policy.unhide?).to be true
      end
    end

    context "when user has tenant admin role" do
      before { user.add_role(:admin, tenant) }

      it "allows access" do
        policy = described_class.new(user, note)
        expect(policy.unhide?).to be true
      end
    end

    context "when user has editor role only" do
      before { user.add_role(:editor, tenant) }

      it "denies access" do
        policy = described_class.new(user, note)
        expect(policy.unhide?).to be false
      end
    end
  end

  describe "Scope" do
    let(:scope) { Note.unscoped }
    let(:policy_scope) { described_class::Scope.new(user, scope) }

    context "when Current.site is present" do
      let!(:our_note) { create(:note, :published, site: site, user: note_owner) }
      let(:other_site) { create(:site, tenant: tenant) }
      let!(:other_note) do
        Current.site = other_site
        note = create(:note, :published, site: other_site, user: create(:user))
        Current.site = site
        note
      end

      it "filters by site_id" do
        result = policy_scope.resolve
        expect(result).to include(our_note)
        expect(result).not_to include(other_note)
      end
    end

    context "when Current.site is nil" do
      before { allow(Current).to receive(:site).and_return(nil) }

      it "returns no notes" do
        result = policy_scope.resolve
        expect(result).to be_empty
      end
    end
  end
end
