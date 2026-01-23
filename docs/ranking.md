# Feed Ranking Algorithm

## Overview

The `FeedRankingService` ranks content items for the public feed by combining three weighted signals:

1. **Freshness** (40%) - How recently the item was published
2. **Source Quality** (30%) - Editorial weight assigned to the source
3. **Engagement** (30%) - User interaction signals (upvotes, comments)

---

## Formula

### Composite Score

```
score = freshness * 0.4 + source_quality * 0.3 + engagement * 0.3
```

All three components are normalized to the 0-1 range before applying weights.

---

## Components

### Freshness Decay (40% weight)

Uses exponential decay with a 24-hour half-life:

```
freshness = 1 / (1 + hours_ago / 24)
```

| Age | Score |
|-----|-------|
| 0 hours | 1.00 |
| 24 hours | 0.50 |
| 48 hours | 0.33 |
| 72 hours | 0.25 |
| 1 week | 0.13 |

**Rationale**: News has a short shelf life. This decay ensures recent content surfaces while still allowing older high-quality items to appear.

### Source Quality Weight (30% weight)

Each `Source` has a `quality_weight` field (default: 1.0, range: 0.0-2.0):

- **0.0-0.5**: Low quality sources (user-generated, unverified)
- **0.5-1.0**: Normal quality sources (default for new sources)
- **1.0-1.5**: High quality sources (established publications)
- **1.5-2.0**: Premium sources (primary/authoritative sources)

**Configuration**: Set via admin interface or programmatically:

```ruby
source.update!(quality_weight: 1.5)
```

### Engagement Score (30% weight)

Combines upvotes and comments:

```
raw_engagement = upvotes_count + (comments_count * 0.5)
engagement = raw_engagement / max_engagement_in_site
```

Comments are weighted at 0.5 relative to upvotes because:
- Comments require more effort than upvotes
- But spam/low-effort comments exist
- This balances signal quality

**Normalization**: Divides by the maximum engagement in the site to produce a 0-1 value. Sites with no engagement default to 0.

---

## Sort Modes

The feed supports three sort modes via the `sort` parameter:

### Ranked (default)

Uses the full composite score formula. Best for homepage and discovery.

```ruby
FeedRankingService.ranked_feed(site: site, filters: { sort: 'ranked' })
```

### Latest

Pure chronological sort by `published_at DESC`. For users who want newest first.

```ruby
FeedRankingService.ranked_feed(site: site, filters: { sort: 'latest' })
```

### Top This Week

Filters to items from the last 7 days, sorted by raw engagement score. For trending/popular content.

```ruby
FeedRankingService.ranked_feed(site: site, filters: { sort: 'top_week' })
```

---

## Filtering

The service supports filtering before ranking:

### By Tag

Filter to items with a specific topic tag:

```ruby
FeedRankingService.ranked_feed(site: site, filters: { tag: 'machine-learning' })
```

### By Content Type

Filter to a specific content type (article, video, podcast, etc.):

```ruby
FeedRankingService.ranked_feed(site: site, filters: { content_type: 'article' })
```

### Combined Filters

All filters can be combined:

```ruby
FeedRankingService.ranked_feed(
  site: site,
  filters: {
    tag: 'ai',
    content_type: 'video',
    sort: 'latest'
  },
  limit: 10,
  offset: 20
)
```

---

## Performance

### Database Indexes

The following indexes optimize ranking queries:

- `(site_id, published_at DESC)` - For chronological queries
- `(site_id, status)` - For filtering published items
- GIN index on `topic_tags` - For tag filtering

### Query Execution

- Ranking SQL is computed in PostgreSQL, not Ruby
- Single query with JOIN to sources table
- Subquery for engagement normalization uses site scope

### Caching Strategy

Consider caching for high-traffic sites:

1. **Page-level caching**: Cache rendered feed HTML with short TTL (60s)
2. **Fragment caching**: Cache individual content cards with item-based keys
3. **Score caching**: Pre-compute scores in a background job for very high volume

---

## Tuning Guide

### When to Adjust Weights

| Scenario | Adjustment |
|----------|------------|
| Content goes stale quickly | Increase `FRESHNESS_WEIGHT` |
| High-quality sources underperforming | Increase `SOURCE_QUALITY_WEIGHT` |
| Viral content not surfacing | Increase `ENGAGEMENT_WEIGHT` |
| Too much clickbait rising | Decrease `ENGAGEMENT_WEIGHT` |

### Modifying Constants

In `app/services/feed_ranking_service.rb`:

```ruby
# Weights must sum to 1.0
FRESHNESS_WEIGHT = 0.4
SOURCE_QUALITY_WEIGHT = 0.3
ENGAGEMENT_WEIGHT = 0.3

# Half-life in hours (lower = faster decay)
DECAY_HALF_LIFE_HOURS = 24
```

### Per-Site Tuning (Future)

Future versions may support per-site ranking configuration via the `Site.config` JSONB field:

```ruby
site.config['ranking'] = {
  'freshness_weight' => 0.5,
  'source_quality_weight' => 0.25,
  'engagement_weight' => 0.25,
  'decay_half_life_hours' => 12
}
```

---

## Future Roadmap

### Personalization

Add user-specific signals:

- Reading history (down-weight seen items)
- Topic preferences (boost preferred tags)
- Source preferences (boost/block sources)

### Machine Learning

Replace hand-tuned weights with learned model:

- Click-through rate prediction
- Dwell time optimization
- A/B testing framework for ranking experiments

### Advanced Signals

Additional ranking signals to consider:

- Content quality score (AI-assessed)
- Author reputation
- External link quality
- Social sharing metrics
- Time-of-day relevance

---

## Related Files

- `app/services/feed_ranking_service.rb` - Core implementation
- `app/controllers/feed_controller.rb` - Feed endpoints
- `app/models/content_item.rb` - Model with feed scopes
- `app/models/source.rb` - Source with quality_weight
- `db/migrate/20260123085712_add_feed_ranking_fields.rb` - Schema

---

*Last Updated: 2026-01-23*
