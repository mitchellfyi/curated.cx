# frozen_string_literal: true

# == Schema Information
#
# Table name: subscriber_tags
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  slug       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  site_id    :bigint           not null
#  tenant_id  :bigint           not null
#
# Indexes
#
#  index_subscriber_tags_on_site_id           (site_id)
#  index_subscriber_tags_on_site_id_and_slug  (site_id,slug) UNIQUE
#  index_subscriber_tags_on_tenant_id         (tenant_id)
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
require "rails_helper"

RSpec.describe SubscriberTag, type: :model do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }

  before do
    allow(Current).to receive(:tenant).and_return(tenant)
    allow(Current).to receive(:site).and_return(site)
  end

  describe "validations" do
    it "validates presence of name" do
      tag = build(:subscriber_tag, site: site, name: nil)

      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to include("can't be blank")
    end

    it "validates name length" do
      tag = build(:subscriber_tag, site: site, name: "a" * 101)

      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to include("is too long (maximum is 100 characters)")
    end

    it "validates presence of slug" do
      tag = build(:subscriber_tag, site: site, slug: nil, name: nil)

      expect(tag).not_to be_valid
      expect(tag.errors[:slug]).to include("can't be blank")
    end

    it "validates slug format with lowercase letters, numbers, hyphens, and underscores" do
      valid_slugs = %w[vip beta-users power_users user123]
      invalid_slugs = [ "VIP", "has spaces", "has.dots", "with@symbol" ]

      valid_slugs.each do |slug|
        tag = build(:subscriber_tag, site: site, slug: slug)
        expect(tag).to be_valid, "Expected slug '#{slug}' to be valid"
      end

      invalid_slugs.each do |slug|
        tag = build(:subscriber_tag, site: site, slug: slug)
        expect(tag).not_to be_valid, "Expected slug '#{slug}' to be invalid"
        expect(tag.errors[:slug]).to include("must contain only lowercase letters, numbers, hyphens, and underscores")
      end
    end

    it "validates uniqueness of slug within site" do
      create(:subscriber_tag, site: site, slug: "unique-slug")
      duplicate = build(:subscriber_tag, site: site, slug: "unique-slug")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:slug]).to include("has already been taken")
    end

    it "allows same slug on different sites" do
      other_site = create(:site, tenant: tenant)
      create(:subscriber_tag, site: site, slug: "shared-slug")
      other_tag = build(:subscriber_tag, site: other_site, slug: "shared-slug")

      expect(other_tag).to be_valid
    end
  end

  describe "callbacks" do
    it "generates slug from name on create" do
      tag = build(:subscriber_tag, site: site, name: "VIP Members", slug: nil)
      tag.save!

      expect(tag.slug).to eq("vip-members")
    end

    it "does not overwrite existing slug" do
      tag = build(:subscriber_tag, site: site, name: "VIP Members", slug: "custom-slug")
      tag.save!

      expect(tag.slug).to eq("custom-slug")
    end

    it "handles special characters in name when generating slug" do
      tag = build(:subscriber_tag, site: site, name: "VIP & Premium Users!", slug: nil)
      tag.save!

      expect(tag.slug).to eq("vip-premium-users")
    end
  end

  describe "associations" do
    it "belongs to site" do
      tag = create(:subscriber_tag, site: site)
      expect(tag.site).to eq(site)
    end

    it "belongs to tenant" do
      tag = create(:subscriber_tag, site: site, tenant: tenant)
      expect(tag.tenant).to eq(tenant)
    end

    it "has many subscriber_taggings" do
      tag = create(:subscriber_tag, site: site)
      user = create(:user)
      subscription = create(:digest_subscription, user: user, site: site)
      tagging = create(:subscriber_tagging, subscriber_tag: tag, digest_subscription: subscription)

      expect(tag.subscriber_taggings).to include(tagging)
    end

    it "has many digest_subscriptions through subscriber_taggings" do
      tag = create(:subscriber_tag, site: site)
      user = create(:user)
      subscription = create(:digest_subscription, user: user, site: site)
      create(:subscriber_tagging, subscriber_tag: tag, digest_subscription: subscription)

      expect(tag.digest_subscriptions).to include(subscription)
    end

    it "destroys subscriber_taggings when destroyed" do
      tag = create(:subscriber_tag, site: site)
      user = create(:user)
      subscription = create(:digest_subscription, user: user, site: site)
      create(:subscriber_tagging, subscriber_tag: tag, digest_subscription: subscription)

      expect { tag.destroy }.to change { SubscriberTagging.count }.by(-1)
    end
  end

  describe "scopes" do
    describe ".alphabetical" do
      it "returns tags ordered by name" do
        tag_z = create(:subscriber_tag, site: site, name: "Zebra")
        tag_a = create(:subscriber_tag, site: site, name: "Alpha")
        tag_m = create(:subscriber_tag, site: site, name: "Mike")

        expect(described_class.alphabetical).to eq([ tag_a, tag_m, tag_z ])
      end
    end
  end

  describe "#to_param" do
    it "returns the slug" do
      tag = create(:subscriber_tag, site: site, slug: "my-tag")
      expect(tag.to_param).to eq("my-tag")
    end
  end
end
