# frozen_string_literal: true

require "rails_helper"

RSpec.describe SearchPolicy, type: :policy do
  let(:user) { create(:user) }
  let(:tenant) { create(:tenant) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }

  before do
    allow(Current).to receive(:tenant).and_return(tenant)
    allow(Current).to receive(:site).and_return(site)
  end

  describe "#index?" do
    context "when tenant does not require login" do
      before { allow(tenant).to receive(:requires_login?).and_return(false) }

      it "allows access for any user" do
        policy = described_class.new(user, :search)
        expect(policy.index?).to be true
      end

      it "allows access for nil user" do
        policy = described_class.new(nil, :search)
        expect(policy.index?).to be true
      end
    end

    context "when tenant requires login" do
      before { allow(tenant).to receive(:requires_login?).and_return(true) }

      it "allows access for logged in user" do
        policy = described_class.new(user, :search)
        expect(policy.index?).to be true
      end

      it "denies access for nil user" do
        policy = described_class.new(nil, :search)
        expect(policy.index?).to be false
      end
    end
  end
end
