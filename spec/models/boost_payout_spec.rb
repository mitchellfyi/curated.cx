# frozen_string_literal: true

require "rails_helper"

RSpec.describe BoostPayout, type: :model do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { create(:site, tenant: tenant) }

  before do
    allow(Current).to receive(:tenant).and_return(tenant)
    allow(Current).to receive(:site).and_return(site)
  end

  describe "associations" do
    it { is_expected.to belong_to(:site) }
  end

  describe "validations" do
    subject { build(:boost_payout, site: site) }

    it { is_expected.to validate_presence_of(:amount) }
    it { is_expected.to validate_numericality_of(:amount).is_greater_than(0) }
    it { is_expected.to validate_presence_of(:period_start) }
    it { is_expected.to validate_presence_of(:period_end) }

    it "validates period_end is after period_start" do
      payout = build(:boost_payout, site: site, period_start: Date.current, period_end: 1.day.ago)

      expect(payout).not_to be_valid
      expect(payout.errors[:period_end]).to include("must be after period start")
    end
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:status).with_values(pending: 0, paid: 1, cancelled: 2) }
  end

  describe "scopes" do
    describe ".recent" do
      it "orders by period_start descending" do
        old_payout = create(:boost_payout, site: site, period_start: 3.months.ago.beginning_of_month, period_end: 3.months.ago.end_of_month)
        new_payout = create(:boost_payout, site: site, period_start: 1.month.ago.beginning_of_month, period_end: 1.month.ago.end_of_month)

        expect(described_class.recent.first).to eq(new_payout)
        expect(described_class.recent.last).to eq(old_payout)
      end
    end

    describe ".for_site" do
      it "filters by site" do
        other_site = create(:site, tenant: tenant)
        payout1 = create(:boost_payout, site: site)
        payout2 = create(:boost_payout, site: other_site)

        expect(described_class.for_site(site)).to include(payout1)
        expect(described_class.for_site(site)).not_to include(payout2)
      end
    end

    describe ".for_period" do
      it "filters by period dates" do
        start_date = 1.month.ago.beginning_of_month.to_date
        end_date = 1.month.ago.end_of_month.to_date

        matching_payout = create(:boost_payout, site: site, period_start: start_date, period_end: end_date)
        different_payout = create(:boost_payout, site: site, period_start: 2.months.ago.beginning_of_month, period_end: 2.months.ago.end_of_month)

        expect(described_class.for_period(start_date, end_date)).to include(matching_payout)
        expect(described_class.for_period(start_date, end_date)).not_to include(different_payout)
      end
    end
  end

  describe "#mark_paid!" do
    context "when pending" do
      it "transitions to paid with timestamp and reference" do
        payout = create(:boost_payout, site: site, status: :pending)
        reference = "PAY-12345"

        freeze_time do
          expect(payout.mark_paid!(reference)).to be true
          payout.reload
          expect(payout.status).to eq("paid")
          expect(payout.paid_at).to eq(Time.current)
          expect(payout.payment_reference).to eq(reference)
        end
      end

      it "transitions without reference" do
        payout = create(:boost_payout, site: site, status: :pending)

        expect(payout.mark_paid!).to be true
        expect(payout.reload.status).to eq("paid")
      end
    end

    context "when not pending" do
      it "returns false for paid payout" do
        payout = create(:boost_payout, :paid, site: site)
        expect(payout.mark_paid!).to be false
      end

      it "returns false for cancelled payout" do
        payout = create(:boost_payout, :cancelled, site: site)
        expect(payout.mark_paid!).to be false
      end
    end
  end

  describe "#cancel!" do
    context "when pending" do
      it "transitions to cancelled" do
        payout = create(:boost_payout, site: site, status: :pending)

        expect(payout.cancel!).to be true
        expect(payout.reload.status).to eq("cancelled")
      end
    end

    context "when paid" do
      it "returns false" do
        payout = create(:boost_payout, :paid, site: site)

        expect(payout.cancel!).to be false
        expect(payout.reload.status).to eq("paid")
      end
    end
  end

  describe "#period_description" do
    it "returns formatted period string" do
      payout = build(:boost_payout, period_start: Date.new(2026, 1, 1), period_end: Date.new(2026, 1, 31))
      expect(payout.period_description).to eq("Jan 2026")
    end
  end

  describe ".calculate_earnings" do
    let(:target_site) { create(:site, tenant: tenant) }
    let(:network_boost) { create(:network_boost, source_site: site, target_site: target_site) }

    it "sums confirmed and paid clicks where site is the source" do
      start_date = 1.month.ago.beginning_of_month
      end_date = 1.month.ago.end_of_month

      create(:boost_click, :confirmed, network_boost: network_boost, earned_amount: 0.50, clicked_at: start_date + 5.days)
      create(:boost_click, :paid, network_boost: network_boost, earned_amount: 0.75, clicked_at: start_date + 10.days)
      create(:boost_click, :pending, network_boost: network_boost, earned_amount: 0.50, clicked_at: start_date + 15.days)
      create(:boost_click, :confirmed, network_boost: network_boost, earned_amount: 1.00, clicked_at: 2.months.ago)

      result = described_class.calculate_earnings(site: site, start_date: start_date, end_date: end_date)
      expect(result).to eq(1.25)
    end

    it "returns 0 when no clicks" do
      result = described_class.calculate_earnings(site: site, start_date: 1.month.ago, end_date: Time.current)
      expect(result).to eq(0)
    end
  end

  describe ".create_for_period!" do
    let(:target_site) { create(:site, tenant: tenant) }
    let(:network_boost) { create(:network_boost, source_site: site, target_site: target_site) }

    context "when there are earnings" do
      before do
        create(:boost_click, :confirmed, network_boost: network_boost, earned_amount: 1.50, clicked_at: 1.month.ago.beginning_of_month + 5.days)
      end

      it "creates a payout with the calculated amount" do
        start_date = 1.month.ago.beginning_of_month.to_date
        end_date = 1.month.ago.end_of_month.to_date

        payout = described_class.create_for_period!(site: site, start_date: start_date, end_date: end_date)

        expect(payout).to be_persisted
        expect(payout.amount).to eq(1.50)
        expect(payout.site).to eq(site)
        expect(payout.period_start).to eq(start_date)
        expect(payout.period_end).to eq(end_date)
      end
    end

    context "when there are no earnings" do
      it "returns nil" do
        start_date = 1.month.ago.beginning_of_month.to_date
        end_date = 1.month.ago.end_of_month.to_date

        payout = described_class.create_for_period!(site: site, start_date: start_date, end_date: end_date)

        expect(payout).to be_nil
      end
    end
  end
end
