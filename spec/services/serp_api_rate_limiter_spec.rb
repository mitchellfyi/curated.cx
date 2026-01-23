# frozen_string_literal: true

require "rails_helper"

RSpec.describe SerpApiRateLimiter, type: :service do
  let(:tenant) { create(:tenant) }
  let(:site) { create(:site, tenant: tenant) }
  let(:source) { create(:source, :serp_api_google_news, site: site) }
  let(:rate_limiter) { described_class.new(source) }

  describe "#allow?" do
    context "when under the rate limit" do
      it "returns true when no import runs exist" do
        expect(rate_limiter.allow?).to be true
      end

      it "returns true when import runs are below the limit" do
        # Rate limit is 10 per hour by default
        5.times do
          create(:import_run, source: source, started_at: 30.minutes.ago)
        end

        expect(rate_limiter.allow?).to be true
      end
    end

    context "when at the rate limit" do
      before do
        10.times do
          create(:import_run, source: source, started_at: 30.minutes.ago)
        end
      end

      it "returns false" do
        expect(rate_limiter.allow?).to be false
      end
    end

    context "when over the rate limit" do
      before do
        15.times do
          create(:import_run, source: source, started_at: 30.minutes.ago)
        end
      end

      it "returns false" do
        expect(rate_limiter.allow?).to be false
      end
    end

    context "with expired import runs (older than 1 hour)" do
      before do
        # Create 15 old import runs
        15.times do
          create(:import_run, source: source, started_at: 2.hours.ago)
        end
        # Create 3 recent import runs
        3.times do
          create(:import_run, source: source, started_at: 30.minutes.ago)
        end
      end

      it "only counts recent import runs and returns true" do
        expect(rate_limiter.allow?).to be true
      end
    end

    context "with custom rate limit" do
      let(:source) do
        create(:source, :serp_api_google_news, site: site, config: {
          "api_key" => "test",
          "query" => "test",
          "rate_limit_per_hour" => 5
        })
      end

      it "respects the custom limit" do
        5.times do
          create(:import_run, source: source, started_at: 30.minutes.ago)
        end

        expect(rate_limiter.allow?).to be false
      end
    end
  end

  describe "#check!" do
    context "when under the rate limit" do
      it "returns true" do
        expect(rate_limiter.check!).to be true
      end
    end

    context "when at or over the rate limit" do
      before do
        10.times do
          create(:import_run, source: source, started_at: 30.minutes.ago)
        end
      end

      it "raises RateLimitExceeded error" do
        expect {
          rate_limiter.check!
        }.to raise_error(described_class::RateLimitExceeded, /Rate limit exceeded/)
      end

      it "includes source id in error message" do
        expect {
          rate_limiter.check!
        }.to raise_error(described_class::RateLimitExceeded, /source #{source.id}/)
      end

      it "includes usage count in error message" do
        expect {
          rate_limiter.check!
        }.to raise_error(described_class::RateLimitExceeded, /10\/10/)
      end
    end
  end

  describe "#remaining" do
    it "returns the full limit when no import runs exist" do
      expect(rate_limiter.remaining).to eq(10)
    end

    it "returns the correct remaining count" do
      3.times do
        create(:import_run, source: source, started_at: 30.minutes.ago)
      end

      expect(rate_limiter.remaining).to eq(7)
    end

    it "returns 0 when at the limit" do
      10.times do
        create(:import_run, source: source, started_at: 30.minutes.ago)
      end

      expect(rate_limiter.remaining).to eq(0)
    end

    it "returns 0 when over the limit" do
      15.times do
        create(:import_run, source: source, started_at: 30.minutes.ago)
      end

      expect(rate_limiter.remaining).to eq(0)
    end
  end

  describe "#limit" do
    it "returns the default limit of 10" do
      expect(rate_limiter.limit).to eq(10)
    end

    context "with string key config" do
      let(:source) do
        create(:source, :serp_api_google_news, site: site, config: {
          "api_key" => "test",
          "query" => "test",
          "rate_limit_per_hour" => 20
        })
      end

      it "returns the custom limit from string config" do
        expect(rate_limiter.limit).to eq(20)
      end
    end

    context "with symbol key config" do
      let(:source) do
        create(:source, :serp_api_google_news, site: site, config: {
          api_key: "test",
          query: "test",
          rate_limit_per_hour: 15
        })
      end

      it "returns the custom limit from symbol config" do
        expect(rate_limiter.limit).to eq(15)
      end
    end
  end

  describe "#used" do
    it "returns 0 when no import runs exist" do
      expect(rate_limiter.used).to eq(0)
    end

    it "returns the count of import runs in the last hour" do
      5.times do
        create(:import_run, source: source, started_at: 30.minutes.ago)
      end

      expect(rate_limiter.used).to eq(5)
    end

    it "excludes import runs older than 1 hour" do
      3.times { create(:import_run, source: source, started_at: 30.minutes.ago) }
      5.times { create(:import_run, source: source, started_at: 2.hours.ago) }

      expect(rate_limiter.used).to eq(3)
    end
  end

  describe "#reset_in" do
    it "returns 0 when no import runs exist" do
      expect(rate_limiter.reset_in).to eq(0)
    end

    it "returns seconds until oldest import run expires" do
      travel_to Time.zone.local(2026, 1, 23, 12, 0, 0) do
        create(:import_run, source: source, started_at: 30.minutes.ago)
        create(:import_run, source: source, started_at: 15.minutes.ago)

        # Oldest is 30 minutes old, so it expires in 30 minutes
        expect(rate_limiter.reset_in).to be_within(5).of(30.minutes.to_i)
      end
    end

    it "returns 0 if the oldest import run has already expired" do
      travel_to Time.zone.local(2026, 1, 23, 12, 0, 0) do
        create(:import_run, source: source, started_at: 61.minutes.ago)

        expect(rate_limiter.reset_in).to eq(0)
      end
    end
  end

  describe "default rate limit constant" do
    it "has a default rate limit of 10" do
      expect(described_class::DEFAULT_RATE_LIMIT_PER_HOUR).to eq(10)
    end
  end
end
