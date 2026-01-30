# frozen_string_literal: true

# == Schema Information
#
# Table name: purchases
#
#  id                         :bigint           not null, primary key
#  amount_cents               :integer          default(0), not null
#  email                      :string           not null
#  purchased_at               :datetime         not null
#  source                     :integer          default("checkout"), not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  digital_product_id         :bigint           not null
#  site_id                    :bigint           not null
#  stripe_checkout_session_id :string
#  stripe_payment_intent_id   :string
#  user_id                    :bigint
#
require "rails_helper"

RSpec.describe Purchase, type: :model do
  let(:tenant) { create(:tenant) }
  let(:site) { create(:site, tenant: tenant) }
  let(:digital_product) { create(:digital_product, :published, site: site) }

  describe "associations" do
    it { should belong_to(:site) }
    it { should belong_to(:digital_product) }
    it { should belong_to(:user).optional }
    it { should have_many(:download_tokens).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:purchase, digital_product: digital_product) }

    it { should validate_presence_of(:email) }
    it { should validate_presence_of(:amount_cents) }
    it { should validate_numericality_of(:amount_cents).only_integer.is_greater_than_or_equal_to(0) }

    describe "email format" do
      it "accepts valid email addresses" do
        purchase = build(:purchase, digital_product: digital_product, email: "valid@example.com")
        expect(purchase).to be_valid
      end

      it "rejects invalid email addresses" do
        purchase = build(:purchase, digital_product: digital_product, email: "invalid-email")
        expect(purchase).not_to be_valid
        expect(purchase.errors[:email]).to be_present
      end
    end

    describe "stripe_checkout_session_id uniqueness" do
      it "validates uniqueness when present" do
        create(:purchase, :from_checkout, digital_product: digital_product, stripe_checkout_session_id: "cs_unique_123")
        duplicate = build(:purchase, digital_product: digital_product, stripe_checkout_session_id: "cs_unique_123")

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:stripe_checkout_session_id]).to include("has already been taken")
      end

      it "allows nil values" do
        create(:purchase, digital_product: digital_product, stripe_checkout_session_id: nil)
        another = build(:purchase, digital_product: digital_product, stripe_checkout_session_id: nil)

        expect(another).to be_valid
      end
    end

    describe "stripe_payment_intent_id uniqueness" do
      it "validates uniqueness when present" do
        create(:purchase, :from_checkout, digital_product: digital_product, stripe_payment_intent_id: "pi_unique_123")
        duplicate = build(:purchase, digital_product: digital_product, stripe_payment_intent_id: "pi_unique_123")

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:stripe_payment_intent_id]).to include("has already been taken")
      end

      it "allows nil values" do
        create(:purchase, digital_product: digital_product, stripe_payment_intent_id: nil)
        another = build(:purchase, digital_product: digital_product, stripe_payment_intent_id: nil)

        expect(another).to be_valid
      end
    end
  end

  describe "enums" do
    it "defines source enum" do
      expect(Purchase.sources).to eq({ "checkout" => 0, "referral" => 1, "admin_grant" => 2 })
    end

    it "defaults to checkout source" do
      purchase = build(:purchase, digital_product: digital_product)
      expect(purchase.source).to eq("checkout")
    end
  end

  describe "scopes" do
    let!(:recent_purchase) { create(:purchase, digital_product: digital_product, purchased_at: 1.hour.ago) }
    let!(:old_purchase) { create(:purchase, digital_product: digital_product, purchased_at: 1.week.ago) }
    let!(:other_product) { create(:digital_product, :published, site: site) }
    let!(:other_product_purchase) { create(:purchase, digital_product: other_product) }

    describe ".recent" do
      it "orders by purchased_at desc" do
        purchases = Purchase.recent
        expect(purchases.first.purchased_at).to be >= purchases.last.purchased_at
      end
    end

    describe ".by_product" do
      it "filters by digital product" do
        expect(Purchase.by_product(digital_product)).to include(recent_purchase, old_purchase)
        expect(Purchase.by_product(digital_product)).not_to include(other_product_purchase)
      end
    end

    describe ".for_email" do
      it "filters by email (downcases search term)" do
        purchase = create(:purchase, digital_product: digital_product, email: "test@example.com")

        expect(Purchase.for_email("test@example.com")).to include(purchase)
        expect(Purchase.for_email("TEST@EXAMPLE.COM")).to include(purchase)
      end
    end
  end

  describe "callbacks" do
    describe "set_purchased_at" do
      it "sets purchased_at on create if blank" do
        freeze_time do
          purchase = create(:purchase, digital_product: digital_product, purchased_at: nil)
          expect(purchase.purchased_at).to eq(Time.current)
        end
      end

      it "preserves explicit purchased_at value" do
        explicit_time = 1.day.ago
        purchase = create(:purchase, digital_product: digital_product, purchased_at: explicit_time)
        expect(purchase.purchased_at).to be_within(1.second).of(explicit_time)
      end
    end
  end

  describe "instance methods" do
    describe "#free?" do
      it "returns true for zero amount" do
        purchase = build(:purchase, :free_purchase, digital_product: digital_product)
        expect(purchase.free?).to be true
      end

      it "returns false for non-zero amount" do
        purchase = build(:purchase, digital_product: digital_product, amount_cents: 999)
        expect(purchase.free?).to be false
      end
    end

    describe "#amount_dollars" do
      it "converts cents to dollars" do
        purchase = build(:purchase, digital_product: digital_product, amount_cents: 1999)
        expect(purchase.amount_dollars).to eq(19.99)
      end
    end

    describe "#formatted_amount" do
      it "returns 'Free' for free purchases" do
        purchase = build(:purchase, :free_purchase, digital_product: digital_product)
        expect(purchase.formatted_amount).to eq("Free")
      end

      it "returns formatted amount for paid purchases" do
        purchase = build(:purchase, digital_product: digital_product, amount_cents: 1999)
        expect(purchase.formatted_amount).to eq("$19.99")
      end

      it "handles single digit cents" do
        purchase = build(:purchase, digital_product: digital_product, amount_cents: 505)
        expect(purchase.formatted_amount).to eq("$5.05")
      end
    end
  end

  describe "source types" do
    it "creates checkout purchase" do
      purchase = create(:purchase, :from_checkout, digital_product: digital_product)
      expect(purchase.checkout?).to be true
      expect(purchase.stripe_checkout_session_id).to be_present
    end

    it "creates referral purchase" do
      purchase = create(:purchase, :from_referral, digital_product: digital_product)
      expect(purchase.referral?).to be true
      expect(purchase.amount_cents).to eq(0)
    end

    it "creates admin grant purchase" do
      purchase = create(:purchase, :admin_grant, digital_product: digital_product)
      expect(purchase.admin_grant?).to be true
      expect(purchase.amount_cents).to eq(0)
    end
  end

  describe "site scoping" do
    it "includes SiteScoped concern" do
      expect(Purchase.ancestors).to include(SiteScoped)
    end

    it "inherits site from digital product" do
      purchase = create(:purchase, digital_product: digital_product)
      expect(purchase.site).to eq(digital_product.site)
    end
  end
end
