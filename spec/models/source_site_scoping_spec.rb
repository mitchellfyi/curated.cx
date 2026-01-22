# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Source, type: :model do
  describe "site scoping" do
    let(:tenant) { create(:tenant) }
    let(:site1) { create(:site, tenant: tenant) }
    let(:site2) { create(:site, tenant: tenant) }

    before do
      Current.site = site1
    end

    it "scopes queries to current site" do
      source1 = create(:source, site: site1)
      source2 = create(:source, site: site2)

      sources = Source.all
      expect(sources).to include(source1)
      expect(sources).not_to include(source2)
    end

    it "validates uniqueness of name scoped to site" do
      create(:source, site: site1, name: "Test Source")

      duplicate = build(:source, site: site1, name: "Test Source")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to be_present
    end

    it "allows same name across different sites" do
      create(:source, site: site1, name: "Test Source")

      source2 = build(:source, site: site2, name: "Test Source")
      expect(source2).to be_valid
    end
  end
end
