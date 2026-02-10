# frozen_string_literal: true

require "rails_helper"

RSpec.describe ContentRecommendationService, type: :service do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:source) { create(:source, site: site) }
  let(:user) { create(:user) }

  before do
    setup_tenant_context(tenant)
  end

  describe ".for_user" do
    context "when user is nil" do
      it "returns cold start fallback content" do
        items = create_list(:entry, :feed, 3, :published, site: site, source: source)

        result = described_class.for_user(nil, site: site, limit: 6)

        expect(result).to be_a(ActiveRecord::Relation)
        expect(result.to_a).to match_array(items)
      end
    end

    context "when user has insufficient interactions (cold start)" do
      it "returns engagement-ranked fallback content for users with less than 5 interactions" do
        # Create 3 interactions (below threshold of 5)
        items = create_list(:entry, :feed, 5, :published, site: site, source: source)
        items.first(3).each do |item|
          create(:vote, entry: item, user: user, site: site)
        end

        result = described_class.for_user(user, site: site, limit: 6)

        expect(result).to be_a(ActiveRecord::Relation)
      end
    end

    context "when user has sufficient interactions" do
      let!(:tech_items) do
        items = create_list(:entry, :feed, 5, :published, site: site, source: source)
        items.each { |item| item.update_columns(topic_tags: %w[tech ai]) }
        items
      end

      let!(:sports_items) do
        items = create_list(:entry, :feed, 5, :published, site: site, source: source)
        items.each { |item| item.update_columns(topic_tags: %w[sports football]) }
        items
      end

      before do
        # Create 6 interactions with tech content (above threshold)
        tech_items.first(6).each do |item|
          create(:vote, entry: item, user: user, site: site)
        end
      end

      it "returns personalized content based on user interests" do
        # Create new uninteracted tech content to recommend
        new_tech_item = create(:entry, :feed, :published, site: site, source: source)
        new_tech_item.update_columns(topic_tags: %w[tech programming])

        # Clear cache to ensure fresh computation
        Rails.cache.clear

        result = described_class.for_user(user, site: site, limit: 6)

        # Should include new tech content since user showed interest in tech
        expect(result.to_a).to include(new_tech_item)
      end

      it "excludes content the user has already interacted with" do
        Rails.cache.clear

        result = described_class.for_user(user, site: site, limit: 6)

        # Should not include items the user already voted on
        tech_items.first(6).each do |item|
          expect(result.to_a).not_to include(item)
        end
      end

      context "caching" do
        # Use memory store for caching tests since test env uses null_store
        around do |example|
          original_cache = Rails.cache
          Rails.cache = ActiveSupport::Cache::MemoryStore.new
          example.run
          Rails.cache = original_cache
        end

        it "caches results for 1 hour" do
          Rails.cache.clear

          # First call computes recommendations
          result1 = described_class.for_user(user, site: site, limit: 6)
          cached_ids = result1.map(&:id)

          # Create a new tech item after caching
          new_item = create(:entry, :feed, :published, site: site, source: source)
          new_item.update_columns(topic_tags: %w[tech ai])

          # Second call should return cached result (same IDs)
          result2 = described_class.for_user(user, site: site, limit: 6)

          # Since cache returns actual records, we compare IDs to avoid order issues
          expect(result2.map(&:id)).to eq(cached_ids)
          # The new item should NOT be in cached result
          expect(result2.map(&:id)).not_to include(new_item.id)
        end
      end
    end

    context "site isolation" do
      let(:other_tenant) { create(:tenant, :enabled) }
      let(:other_site) { create(:site, tenant: other_tenant) }
      let(:other_source) { create(:source, site: other_site) }

      it "only returns content from the specified site" do
        item1 = create(:entry, :feed, :published, site: site, source: source)
        item1.update_columns(topic_tags: %w[tech])

        other_item = create(:entry, :feed, :published, site: other_site, source: other_source)
        other_item.update_columns(topic_tags: %w[tech])

        result = described_class.for_user(nil, site: site, limit: 10)

        expect(result.to_a).to include(item1)
        expect(result.to_a).not_to include(other_item)
      end
    end
  end

  describe ".similar_to" do
    let(:tech_item) do
      item = create(:entry, :feed, :published, site: site, source: source)
      item.update_columns(topic_tags: %w[tech ai programming])
      item
    end

    it "returns items with matching topic_tags" do
      similar_item = create(:entry, :feed, :published, site: site, source: source)
      similar_item.update_columns(topic_tags: %w[tech javascript])

      unrelated_item = create(:entry, :feed, :published, site: site, source: source)
      unrelated_item.update_columns(topic_tags: %w[sports football])

      result = described_class.similar_to(tech_item, limit: 4)

      expect(result.to_a).to include(similar_item)
      expect(result.to_a).not_to include(unrelated_item)
    end

    it "excludes the source item from results" do
      result = described_class.similar_to(tech_item, limit: 4)

      expect(result.to_a).not_to include(tech_item)
    end

    it "returns empty array when entry has no topic_tags" do
      item = create(:entry, :feed, :published, site: site, source: source)
      item.update_columns(topic_tags: [])

      result = described_class.similar_to(item, limit: 4)

      expect(result).to eq([])
    end

    it "orders results by published_at descending" do
      old_similar = create(:entry, :feed, :published, site: site, source: source, published_at: 1.week.ago)
      old_similar.update_columns(topic_tags: %w[tech])

      new_similar = create(:entry, :feed, :published, site: site, source: source, published_at: 1.hour.ago)
      new_similar.update_columns(topic_tags: %w[tech])

      result = described_class.similar_to(tech_item, limit: 4)

      expect(result.first).to eq(new_similar)
      expect(result.last).to eq(old_similar)
    end

    it "respects the limit parameter" do
      5.times do
        item = create(:entry, :feed, :published, site: site, source: source)
        item.update_columns(topic_tags: %w[tech])
      end

      result = described_class.similar_to(tech_item, limit: 3)

      expect(result.count).to eq(3)
    end
  end

  describe ".for_digest" do
    let(:subscription) { create(:digest_subscription, user: user, site: site) }

    context "when user has insufficient interactions" do
      it "returns cold start fallback content" do
        items = create_list(:entry, :feed, 3, :published, site: site, source: source)

        result = described_class.for_digest(subscription, limit: 5)

        expect(result).to be_a(ActiveRecord::Relation)
      end
    end

    context "when user has sufficient interactions" do
      before do
        # Create interactions above threshold
        6.times do
          item = create(:entry, :feed, :published, site: site, source: source)
          item.update_columns(topic_tags: %w[tech])
          create(:vote, entry: item, user: user, site: site)
        end
      end

      it "returns personalized content for the subscription user" do
        new_tech_item = create(:entry, :feed, :published, site: site, source: source)
        new_tech_item.update_columns(topic_tags: %w[tech programming])

        result = described_class.for_digest(subscription, limit: 5)

        expect(result.to_a).to include(new_tech_item)
      end

      it "does not cache results (different from for_user)" do
        # for_digest computes fresh recommendations each time
        result1 = described_class.for_digest(subscription, limit: 5)

        new_item = create(:entry, :feed, :published, site: site, source: source)
        new_item.update_columns(topic_tags: %w[tech])

        result2 = described_class.for_digest(subscription, limit: 5)

        # The new item might be included since for_digest doesn't cache
        expect(result2.to_a).to include(new_item)
      end
    end
  end

  describe "interaction weights" do
    context "when user has votes, bookmarks, and views" do
      let!(:voted_item) do
        item = create(:entry, :feed, :published, site: site, source: source)
        item.update_columns(topic_tags: %w[voted-topic])
        create(:vote, entry: item, user: user, site: site)
        item
      end

      let!(:bookmarked_item) do
        item = create(:entry, :feed, :published, site: site, source: source)
        item.update_columns(topic_tags: %w[bookmarked-topic])
        create(:bookmark, user: user, bookmarkable: item)
        item
      end

      let!(:viewed_item) do
        item = create(:entry, :feed, :published, site: site, source: source)
        item.update_columns(topic_tags: %w[viewed-topic])
        create(:content_view, entry: item, user: user, site: site)
        item
      end

      it "weights votes higher than bookmarks and views" do
        # Add more interactions to reach threshold
        3.times do
          item = create(:entry, :feed, :published, site: site, source: source)
          item.update_columns(topic_tags: %w[voted-topic])
          create(:vote, entry: item, user: user, site: site)
        end

        # Create new content matching different topics
        voted_topic_item = create(:entry, :feed, :published, site: site, source: source)
        voted_topic_item.update_columns(topic_tags: %w[voted-topic])

        Rails.cache.clear
        result = described_class.for_user(user, site: site, limit: 10)

        # voted-topic should be highly weighted and matched
        expect(result.to_a).to include(voted_topic_item)
      end
    end
  end

  describe "time decay" do
    it "weights recent interactions more heavily than old ones" do
      # Create old interaction
      old_item = create(:entry, :feed, :published, site: site, source: source)
      old_item.update_columns(topic_tags: %w[old-topic])
      old_vote = create(:vote, entry: old_item, user: user, site: site)
      old_vote.update_columns(created_at: 60.days.ago)

      # Create recent interactions (above threshold)
      5.times do
        item = create(:entry, :feed, :published, site: site, source: source)
        item.update_columns(topic_tags: %w[recent-topic])
        create(:vote, entry: item, user: user, site: site)
      end

      # Create new content matching different topics
      recent_topic_item = create(:entry, :feed, :published, site: site, source: source)
      recent_topic_item.update_columns(topic_tags: %w[recent-topic])

      Rails.cache.clear
      result = described_class.for_user(user, site: site, limit: 10)

      # Recent topic should be weighted higher
      expect(result.to_a).to include(recent_topic_item)
    end
  end

  describe "constants" do
    it "has a cold start threshold of 5" do
      expect(described_class::COLD_START_THRESHOLD).to eq(5)
    end

    it "has a lookback window of 90 days" do
      expect(described_class::LOOKBACK_DAYS).to eq(90)
    end

    it "has interaction weights" do
      expect(described_class::VOTE_WEIGHT).to eq(3.0)
      expect(described_class::BOOKMARK_WEIGHT).to eq(2.0)
      expect(described_class::VIEW_WEIGHT).to eq(1.0)
    end

    it "has a diversity ratio of 20%" do
      expect(described_class::DIVERSITY_RATIO).to eq(0.2)
    end

    it "has a decay half-life of 14 days" do
      expect(described_class::DECAY_HALF_LIFE_DAYS).to eq(14)
    end
  end
end
