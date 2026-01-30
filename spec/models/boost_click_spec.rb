# frozen_string_literal: true

require "rails_helper"

RSpec.describe BoostClick, type: :model do
  let(:tenant) { create(:tenant, :enabled) }
  let(:source_site) { create(:site, tenant: tenant) }
  let(:target_site) { create(:site, tenant: tenant) }
  let(:network_boost) { create(:network_boost, source_site: source_site, target_site: target_site) }
  let(:user) { create(:user) }
  let(:subscription) { create(:digest_subscription, user: user, site: target_site) }

  before do
    allow(Current).to receive(:tenant).and_return(tenant)
    allow(Current).to receive(:site).and_return(target_site)
  end

  describe "associations" do
    it { is_expected.to belong_to(:network_boost) }
    it { is_expected.to belong_to(:digest_subscription).optional }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:clicked_at) }
    it { is_expected.to validate_numericality_of(:earned_amount).is_greater_than_or_equal_to(0).allow_nil }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:status).with_values(pending: 0, confirmed: 1, paid: 2, cancelled: 3) }
  end

  describe "scopes" do
    describe ".recent" do
      it "orders by clicked_at descending" do
        old_click = create(:boost_click, network_boost: network_boost, clicked_at: 2.days.ago)
        new_click = create(:boost_click, network_boost: network_boost, clicked_at: 1.day.ago)

        expect(described_class.recent.first).to eq(new_click)
        expect(described_class.recent.last).to eq(old_click)
      end
    end

    describe ".today" do
      it "returns clicks from today" do
        today_click = create(:boost_click, network_boost: network_boost, clicked_at: Time.current)
        yesterday_click = create(:boost_click, network_boost: network_boost, clicked_at: 1.day.ago)

        expect(described_class.today).to include(today_click)
        expect(described_class.today).not_to include(yesterday_click)
      end
    end

    describe ".converted" do
      it "returns clicks with converted_at set" do
        converted_click = create(:boost_click, network_boost: network_boost, converted_at: Time.current)
        unconverted_click = create(:boost_click, network_boost: network_boost, converted_at: nil)

        expect(described_class.converted).to include(converted_click)
        expect(described_class.converted).not_to include(unconverted_click)
      end
    end

    describe ".unconverted" do
      it "returns clicks without converted_at" do
        converted_click = create(:boost_click, network_boost: network_boost, converted_at: Time.current)
        unconverted_click = create(:boost_click, network_boost: network_boost, converted_at: nil)

        expect(described_class.unconverted).to include(unconverted_click)
        expect(described_class.unconverted).not_to include(converted_click)
      end
    end

    describe ".within_attribution_window" do
      let(:ip_hash) { "test_ip_hash" }

      it "returns unconverted clicks within 30 days" do
        recent_click = create(:boost_click, network_boost: network_boost, ip_hash: ip_hash, clicked_at: 15.days.ago)
        old_click = create(:boost_click, network_boost: network_boost, ip_hash: ip_hash, clicked_at: 35.days.ago)

        expect(described_class.within_attribution_window(ip_hash)).to include(recent_click)
        expect(described_class.within_attribution_window(ip_hash)).not_to include(old_click)
      end

      it "excludes already converted clicks" do
        converted_click = create(:boost_click, network_boost: network_boost, ip_hash: ip_hash, clicked_at: 10.days.ago, converted_at: 5.days.ago)

        expect(described_class.within_attribution_window(ip_hash)).not_to include(converted_click)
      end
    end
  end

  describe "#confirm!" do
    context "when pending" do
      it "transitions to confirmed" do
        click = create(:boost_click, network_boost: network_boost, status: :pending)

        expect(click.confirm!).to be true
        expect(click.reload.status).to eq("confirmed")
      end
    end

    context "when not pending" do
      it "returns false for confirmed click" do
        click = create(:boost_click, network_boost: network_boost, status: :confirmed)
        expect(click.confirm!).to be false
      end

      it "returns false for paid click" do
        click = create(:boost_click, network_boost: network_boost, status: :paid)
        expect(click.confirm!).to be false
      end

      it "returns false for cancelled click" do
        click = create(:boost_click, network_boost: network_boost, status: :cancelled)
        expect(click.confirm!).to be false
      end
    end
  end

  describe "#mark_paid!" do
    context "when confirmed" do
      it "transitions to paid" do
        click = create(:boost_click, network_boost: network_boost, status: :confirmed)

        expect(click.mark_paid!).to be true
        expect(click.reload.status).to eq("paid")
      end
    end

    context "when not confirmed" do
      it "returns false for pending click" do
        click = create(:boost_click, network_boost: network_boost, status: :pending)
        expect(click.mark_paid!).to be false
      end

      it "returns false for paid click" do
        click = create(:boost_click, network_boost: network_boost, status: :paid)
        expect(click.mark_paid!).to be false
      end
    end
  end

  describe "#cancel!" do
    context "when pending" do
      it "transitions to cancelled" do
        click = create(:boost_click, network_boost: network_boost, status: :pending)

        expect(click.cancel!).to be true
        expect(click.reload.status).to eq("cancelled")
      end
    end

    context "when confirmed" do
      it "transitions to cancelled" do
        click = create(:boost_click, network_boost: network_boost, status: :confirmed)

        expect(click.cancel!).to be true
        expect(click.reload.status).to eq("cancelled")
      end
    end

    context "when paid" do
      it "returns false" do
        click = create(:boost_click, network_boost: network_boost, status: :paid)

        expect(click.cancel!).to be false
        expect(click.reload.status).to eq("paid")
      end
    end
  end

  describe "#mark_converted!" do
    context "when not already converted" do
      it "marks the click as converted with subscription" do
        click = create(:boost_click, network_boost: network_boost, converted_at: nil)

        freeze_time do
          expect(click.mark_converted!(subscription)).to be true
          click.reload
          expect(click.converted_at).to eq(Time.current)
          expect(click.digest_subscription).to eq(subscription)
        end
      end
    end

    context "when already converted" do
      it "returns false" do
        click = create(:boost_click, network_boost: network_boost, converted_at: 1.day.ago)

        expect(click.mark_converted!(subscription)).to be false
      end
    end
  end

  describe "#target_site" do
    it "delegates to network_boost" do
      click = build(:boost_click, network_boost: network_boost)
      expect(click.target_site).to eq(target_site)
    end
  end

  describe "#source_site" do
    it "delegates to network_boost" do
      click = build(:boost_click, network_boost: network_boost)
      expect(click.source_site).to eq(source_site)
    end
  end

  describe ".count_for_boost" do
    it "returns count of clicks for a boost since given date" do
      create(:boost_click, network_boost: network_boost, clicked_at: 10.days.ago)
      create(:boost_click, network_boost: network_boost, clicked_at: 5.days.ago)
      create(:boost_click, network_boost: network_boost, clicked_at: 35.days.ago)

      expect(described_class.count_for_boost(network_boost.id, since: 30.days.ago)).to eq(2)
    end
  end

  describe ".conversion_rate" do
    it "calculates conversion rate as percentage" do
      create(:boost_click, network_boost: network_boost, clicked_at: 5.days.ago, converted_at: 4.days.ago)
      create(:boost_click, network_boost: network_boost, clicked_at: 5.days.ago, converted_at: nil)
      create(:boost_click, network_boost: network_boost, clicked_at: 5.days.ago, converted_at: nil)
      create(:boost_click, network_boost: network_boost, clicked_at: 5.days.ago, converted_at: nil)

      expect(described_class.conversion_rate(network_boost.id, since: 30.days.ago)).to eq(25.0)
    end

    it "returns 0 when no clicks" do
      expect(described_class.conversion_rate(network_boost.id, since: 30.days.ago)).to eq(0.0)
    end
  end
end
