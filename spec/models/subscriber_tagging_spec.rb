# frozen_string_literal: true

# == Schema Information
#
# Table name: subscriber_taggings
#
#  id                     :bigint           not null, primary key
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  digest_subscription_id :bigint           not null
#  subscriber_tag_id      :bigint           not null
#
# Indexes
#
#  index_subscriber_taggings_on_digest_subscription_id  (digest_subscription_id)
#  index_subscriber_taggings_on_subscriber_tag_id       (subscriber_tag_id)
#  index_subscriber_taggings_uniqueness                 (digest_subscription_id,subscriber_tag_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (digest_subscription_id => digest_subscriptions.id)
#  fk_rails_...  (subscriber_tag_id => subscriber_tags.id)
#
require "rails_helper"

RSpec.describe SubscriberTagging, type: :model do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:user) { create(:user) }
  let(:subscription) { create(:digest_subscription, user: user, site: site) }
  let(:tag) { create(:subscriber_tag, site: site) }

  before do
    allow(Current).to receive(:tenant).and_return(tenant)
    allow(Current).to receive(:site).and_return(site)
  end

  describe "validations" do
    it "validates uniqueness of subscriber_tag_id within digest_subscription" do
      create(:subscriber_tagging, digest_subscription: subscription, subscriber_tag: tag)
      duplicate = build(:subscriber_tagging, digest_subscription: subscription, subscriber_tag: tag)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:subscriber_tag_id]).to include("already assigned to this subscription")
    end

    it "allows same tag on different subscriptions" do
      other_user = create(:user)
      other_subscription = create(:digest_subscription, user: other_user, site: site)
      create(:subscriber_tagging, digest_subscription: subscription, subscriber_tag: tag)

      other_tagging = build(:subscriber_tagging, digest_subscription: other_subscription, subscriber_tag: tag)
      expect(other_tagging).to be_valid
    end

    it "allows same subscription to have different tags" do
      other_tag = create(:subscriber_tag, site: site, name: "Other Tag")
      create(:subscriber_tagging, digest_subscription: subscription, subscriber_tag: tag)

      other_tagging = build(:subscriber_tagging, digest_subscription: subscription, subscriber_tag: other_tag)
      expect(other_tagging).to be_valid
    end
  end

  describe "associations" do
    it "belongs to digest_subscription" do
      tagging = create(:subscriber_tagging, digest_subscription: subscription, subscriber_tag: tag)
      expect(tagging.digest_subscription).to eq(subscription)
    end

    it "belongs to subscriber_tag" do
      tagging = create(:subscriber_tagging, digest_subscription: subscription, subscriber_tag: tag)
      expect(tagging.subscriber_tag).to eq(tag)
    end
  end
end
