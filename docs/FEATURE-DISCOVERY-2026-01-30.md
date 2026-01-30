# Feature Discovery Report

## Executive Summary

**Project**: Curated.cx - Multi-tenant content network platform
**Discovery Scope**: Full (Competitors, Industry Trends, Gaps, UX)
**Date**: 2026-01-30

### Key Findings

1. **Newsletter growth tools are table stakes** - Referral programs, email automation, and subscriber segmentation are expected features. beehiiv's referral program drives 5-10% of growth; Morning Brew grew 15x in 18 months using referrals.

2. **Personalization is the #1 trend for 2026** - AI-powered recommendation engines improve conversion by 202%. The market is at $12B. Netflix's recommendations drive 80% of viewing time.

3. **Content platforms are becoming multimedia hubs** - Substack, beehiiv, and Ghost now support live video, podcasts, and digital products. beehiiv's Nov 2025 expansion added digital products with zero commissions.

4. **Curated's multi-tenant architecture is a unique advantage** - While Ghost, Substack, and Medium are single-tenant, Curated can leverage network effects across sites (like beehiiv's Boosts but built-in).

5. **Social features drive discovery** - Substack Notes drives 70% of subscriber growth for some creators. 32M new subscribers came from Substack's internal discovery in Q4 2025.

### Top Recommendations

| Rank | Feature | RICE Score | Rationale |
|------|---------|------------|-----------|
| 1 | Newsletter Referral Program | 270 | Proven 5-15% growth driver, builds on existing digest system |
| 2 | Email Automation Sequences | 240 | Industry standard, enables onboarding & re-engagement |
| 3 | Personalized Recommendations | 225 | 202% conversion improvement, leverages existing data |
| 4 | Cross-Network Discovery & Boosts | 216 | Unique differentiator using multi-tenant architecture |
| 5 | Content Scheduling | 180 | Expected feature, relatively simple to implement |

---

## Research Findings

### Competitor Landscape

| Competitor | Strengths | Weaknesses | Notable Features We Lack |
|------------|-----------|------------|--------------------------|
| **Ghost** | 0% platform fees, fast performance (Node.js), strong SEO, member portal | Limited beyond publishing, no visual builders | Discovery engine (Nov 2025), networked publishing (Aug 2025), native analytics |
| **Substack** | Large network (5M+ paid subs), Notes social layer, built-in discovery | 10% revenue cut, limited automation until 2026 | Notes (70% growth driver), email automation, live video notifications |
| **beehiiv** | Zero commission on subscriptions, $1M+/month ad network, generous free tier | Less established brand | Referral programs, Boosts, digital products (zero commission), AI website builder |
| **Medium** | 100M monthly users, human curation team, strong SEO | 30% revenue cut, limited customization | Publications system, partner program distribution |
| **Kit (ConvertKit)** | 28+ automation templates, creator network, free plan to 10k subs | Gets expensive at scale | Visual automation builder, subscriber scoring, creator recommendations |

### What Competitors Do Better Than Curated

1. **Growth Tools**: Referral programs (beehiiv, Kit), internal discovery (Substack), Boosts (beehiiv)
2. **Email Automation**: Welcome sequences, re-engagement campaigns, visual builders
3. **Monetization Options**: Digital products (beehiiv, Kit), tipping, multiple payment tiers
4. **Social/Community**: Substack Notes, Ghost communities, live video
5. **Personalization**: Recommendation engines, subscriber segmentation, dynamic content

### What Curated Does Better

1. **Multi-tenant Architecture**: True network of interconnected sites vs isolated publications
2. **Content Aggregation**: Sophisticated source ingestion (RSS, SERP API, scrapers) with AI editorialisation
3. **Listings Marketplace**: Built-in directory/classifieds with Stripe payments
4. **Quality Infrastructure**: 12 quality gates, comprehensive testing, WCAG compliance
5. **AI Integration**: Automated tagging, summarization, editorialisation pipeline

### Gaps in the Market / Opportunities

1. **Network-native growth** - No competitor has built-in cross-site promotion like Curated could offer
2. **Content + Commerce** - Curated's listings + potential digital products creates a unique content commerce hybrid
3. **AI-first curation** - Most platforms treat AI as add-on; Curated has it built into ingestion pipeline

---

### Feature Gap Analysis

| Missing Feature | Priority | Effort | Impact | Notes |
|-----------------|----------|--------|--------|-------|
| Referral Program | P1 | M | High | Proven growth driver, synergizes with digest system |
| Email Automation | P1 | M | High | Industry standard, enables lifecycle marketing |
| Personalized Recommendations | P1 | M | High | Leverages existing interaction data |
| Cross-Network Boosts | P1 | S | High | Unique to multi-tenant architecture |
| Content Scheduling | P2 | S | Medium | Expected feature, table stakes |
| Community Chat | P2 | M | Medium | Drives engagement & retention |
| Digital Products | P2 | S | Medium | Additional revenue stream |
| Subscriber Segmentation | P2 | M | Medium | Enables targeted content |
| Live Video | P3 | M | Medium | High engagement but complex |
| Social Notes | P2 | M | Medium | Discovery driver |

---

### UX Improvement Opportunities

| Area | Issue | Suggested Improvement |
|------|-------|----------------------|
| Onboarding | No email confirmation or welcome sequence | Add email verification + automated welcome series |
| Subscriber Experience | Generic digest for all | Personalized content + interest preferences |
| Publisher Dashboard | Basic analytics | Enhanced metrics, content calendar, growth insights |
| Mobile Experience | Not specifically optimized | Responsive improvements, PWA consideration |
| Discovery | Category browsing only | Personalized "For You" feed, trending content |

---

## Recommended Roadmap

### Now (Next Sprint) - Growth Foundation

1. **Newsletter Referral Program** (002-001)
   - Highest RICE score (270)
   - Leverages existing DigestSubscription infrastructure
   - Immediate organic growth impact

2. **Email Automation Sequences** (002-002)
   - Industry standard expectation
   - Enables welcome series, re-engagement
   - Foundation for lifecycle marketing

### Next (This Quarter) - Personalization & Network

3. **Personalized Content Recommendations** (002-003)
   - High impact on engagement
   - Builds on existing Vote, Bookmark, ContentItem data
   - Competitive parity with major platforms

4. **Cross-Network Discovery & Boosts** (002-004)
   - Unique differentiator leveraging multi-tenant architecture
   - Creates paid growth channel within network
   - Potential revenue stream for platform

5. **Content Scheduling** (002-005)
   - Table stakes feature
   - Relatively quick implementation
   - Improves publisher workflow

### Later (This Year) - Community & Commerce

6. **Community Chat/Discussions** (003-001)
   - Builds engagement and retention
   - Transforms one-way broadcast to two-way community

7. **Digital Products Marketplace** (003-003)
   - Synergizes with referral program (rewards)
   - New revenue stream for publishers

8. **Subscriber Segmentation** (003-004)
   - Enables targeted content delivery
   - Foundation for A/B testing

9. **Social Notes** (003-005)
   - Proven growth driver on Substack
   - Increases network effect

10. **Live Video** (003-002)
    - Complex but high engagement
    - Consider simpler YouTube embed first

---

## Feature Specifications

### Feature 1: Newsletter Referral Program

**Problem**: Publishers have no automated way to grow through existing subscribers. All growth requires manual effort or paid acquisition.

**Solution**: A referral system where subscribers earn rewards for referring new subscribers.

**User Value**: Organic growth at minimal cost, increased subscriber engagement and loyalty

**RICE Score**: 270
- Reach: 1000 (all sites with active digest subscriptions)
- Impact: 3 (massive - proven 5-15% growth impact)
- Confidence: 90% (well-documented success at competitors)
- Effort: 1 person-week

**User Stories**:
- As a subscriber, I want to share a referral link so that I can earn rewards
- As a publisher, I want to see referral metrics so that I can understand my organic growth
- As a subscriber, I want to track my referrals so that I know when I've earned rewards

**Success Criteria**:
- [ ] 5%+ of new subscribers come from referrals within 3 months
- [ ] Referral share rate > 2% of active subscribers
- [ ] 50%+ of referred subscribers remain active after 30 days

**Scope**:
- In: Referral tracking, unique codes, configurable rewards, share widgets, dashboards
- Out: Automated reward fulfillment (manual initially), fraud ML detection

---

### Feature 2: Email Automation Sequences

**Problem**: Publishers can only send periodic digests. No way to automate onboarding, nurturing, or re-engagement.

**Solution**: Visual email automation builder with triggered sequences.

**User Value**: Better subscriber onboarding, higher retention, less manual work

**RICE Score**: 240
- Reach: 800 (publishers with active email lists)
- Impact: 3 (high - improves lifetime value and retention)
- Confidence: 100% (proven feature at all competitors)
- Effort: 1 person-week

**User Stories**:
- As a publisher, I want to create a welcome sequence so that new subscribers get oriented
- As a publisher, I want to send re-engagement emails so that inactive subscribers return
- As a subscriber, I want to receive a personalized onboarding experience

**Success Criteria**:
- [ ] 80%+ of publishers with digests create at least one automation
- [ ] Welcome sequences achieve 50%+ open rates
- [ ] Re-engagement sequences recover 10%+ of inactive subscribers

**Scope**:
- In: Welcome, onboarding, milestone, re-engagement triggers; delay configuration; templates
- Out: Complex branching logic, A/B testing within sequences (future)

---

### Feature 3: Personalized Content Recommendations

**Problem**: All users see the same feed. No personalization based on interests or behavior.

**Solution**: Recommendation engine using interaction signals to personalize the feed.

**User Value**: More relevant content, increased engagement, better discovery

**RICE Score**: 225
- Reach: 1500 (all site visitors)
- Impact: 2 (significant engagement improvement)
- Confidence: 75% (depends on implementation quality)
- Effort: 1 person-week

**User Stories**:
- As a reader, I want to see content relevant to my interests so that I spend less time searching
- As a reader, I want "more like this" suggestions so that I can dive deeper into topics
- As a publisher, I want content to reach interested readers so that engagement increases

**Success Criteria**:
- [ ] Users who see recommendations have 20%+ higher page views
- [ ] Click-through rate on recommendations > 5%
- [ ] Time on site increases 15%+ for logged-in users

**Scope**:
- In: "For You" section, similar content, email recommendations; behavior tracking
- Out: Complex ML models (start with collaborative filtering), cross-site recommendations

---

### Feature 4: Cross-Network Discovery & Boosts

**Problem**: Each tenant site operates in isolation. No mechanism to leverage network effects.

**Solution**: A "Boosts" system for paid cross-promotion between network sites.

**User Value**: Growth through network effects, additional revenue stream

**RICE Score**: 216
- Reach: 600 (publishers in network)
- Impact: 3 (unique differentiator)
- Confidence: 80% (beehiiv proves the model)
- Effort: 0.67 person-weeks

**User Stories**:
- As a publisher, I want to recommend other sites to my subscribers so that I can earn money
- As a publisher, I want to pay for recommendations so that I can grow my subscriber base
- As a network user, I want to discover related sites so that I find more relevant content

**Success Criteria**:
- [ ] 50%+ of sites opt into boost program
- [ ] 2%+ click-through rate on boost recommendations
- [ ] Measurable subscriber growth from cross-promotion

**Scope**:
- In: Boost marketplace, CPC pricing, recommendation widgets, earnings dashboard
- Out: Stripe Connect payouts (manual initially), fraud detection

---

### Feature 5: Content Scheduling

**Problem**: Content publishes immediately or requires manual intervention. No scheduling.

**Solution**: Add scheduled publishing with calendar view.

**User Value**: Consistent posting schedule, optimal timing, better workflow

**RICE Score**: 180
- Reach: 800 (all publishers)
- Impact: 1.5 (quality of life improvement)
- Confidence: 100% (straightforward feature)
- Effort: 0.67 person-weeks

**User Stories**:
- As a publisher, I want to schedule content for later so that I can batch my work
- As a publisher, I want to see a calendar of scheduled content so that I can plan
- As a publisher, I want to set optimal posting times so that content reaches more people

**Success Criteria**:
- [ ] 30%+ of manual content items use scheduling
- [ ] Publishers use calendar view weekly
- [ ] No missed scheduled publishes

**Scope**:
- In: scheduled_for field, publish job, calendar view, timezone support
- Out: Optimal time suggestions (future), bulk scheduling

---

## Tasks Created

High Priority (002):
1. `.doyaken/tasks/2.todo/002-001-newsletter-subscriber-referral-program.md`
2. `.doyaken/tasks/2.todo/002-002-email-automation-sequences.md`
3. `.doyaken/tasks/2.todo/002-003-personalized-content-recommendations.md`
4. `.doyaken/tasks/2.todo/002-004-cross-network-discovery-boosts.md`
5. `.doyaken/tasks/2.todo/002-005-content-scheduling-publish-queue.md`

Medium Priority (003):
6. `.doyaken/tasks/2.todo/003-001-community-chat-discussions.md`
7. `.doyaken/tasks/2.todo/003-002-live-video-streaming.md`
8. `.doyaken/tasks/2.todo/003-003-digital-products-marketplace.md`
9. `.doyaken/tasks/2.todo/003-004-subscriber-segmentation.md`
10. `.doyaken/tasks/2.todo/003-005-social-notes-short-form.md`

---

## Sources

### Ghost CMS
- [Ghost Official](https://ghost.org/)
- [Ghost Review 2026 - Usereviews.io](https://usereviews.io/tools/ghost)
- [Ghost CMS Review - Azeem Safi](https://azeemsafi.me/ghost-cms-review/)
- [Ghost Changelog](https://ghost.org/changelog/)

### Substack
- [Substack Statistics 2026 - Fueler](https://fueler.io/blog/substack-usage-revenue-valuation-growth-statistics)
- [10 Trends Shaping Substack 2026](https://writebuildscale.substack.com/p/10-trends-that-will-shape-substack)
- [Substack Pricing 2026 - SchoolMaker](https://www.schoolmaker.com/blog/substack-pricing)

### beehiiv
- [beehiiv Official](https://www.beehiiv.com/)
- [State of Newsletters 2026 - beehiiv](https://www.beehiiv.com/blog/the-state-of-newsletters-2026)
- [beehiiv Platform Expansion - TechCrunch](https://techcrunch.com/2025/11/13/newsletter-platform-beehiiv-adds-ai-website-building-creator-tools-in-major-expansion/)
- [beehiiv Referral Program](https://www.beehiiv.com/features/referral-program)

### Medium
- [Medium Review - Writer's Digest](https://www.writersdigest.com/an-honest-review-of-the-medium-publishing-platform-article-market)
- [Writing on Medium - Shopify](https://www.shopify.com/blog/writing-on-medium)

### Kit (ConvertKit)
- [Kit Official](https://kit.com/)
- [Kit Review 2026 - Email Tool Tester](https://www.emailtooltester.com/en/reviews/convertkit/)

### Industry Trends
- [Content Marketing Trends 2026 - Creaitor](https://www.creaitor.ai/blog/content-trends-2026)
- [AI Personalization Statistics - DemandSage](https://www.demandsage.com/personalization-statistics/)
- [Newsletter Referral Programs - Referral Rock](https://referralrock.com/blog/newsletter-referral-program/)
