# Task: Cross-Network Discovery & Boosts

## Metadata

| Field       | Value                                                  |
| ----------- | ------------------------------------------------------ |
| ID          | `002-004-cross-network-discovery-boosts`               |
| Status      | `todo`                                                 |
| Priority    | `002` High                                             |
| Created     | `2026-01-30 15:30`                                     |
| Started     |                                                        |
| Completed   |                                                        |
| Blocked By  |                                                        |
| Blocks      |                                                        |
| Assigned To |                                                        |
| Assigned At |                                                        |

---

## Context

Why does this task exist? What problem does it solve?

- **Unique Advantage**: Curated is a multi-tenant network (curated.cx, ainews.cx, construction.cx, dayz.cx). This is a differentiator vs single-tenant platforms like Ghost or Substack.
- **Competitive Feature**: beehiiv's Boosts feature pays $1M+/month to publishers. Ghost added networked publishing in Aug 2025. Substack's internal discovery drove 32M new subscribers.
- **Monetization**: Cross-promotion creates a paid growth channel within the network.
- **RICE Score**: 216 (Reach: 600, Impact: 3, Confidence: 80%, Effort: 0.67 person-weeks)

**Problem**: Each tenant site operates in isolation. There's no mechanism for publishers to grow by leveraging the network effect, and the curated.cx hub doesn't facilitate inter-site discovery.

**Solution**: A "Boosts" system where publishers can recommend other network sites to their subscribers and get paid for conversions, plus enhanced cross-network discovery on the hub.

---

## Acceptance Criteria

All must be checked before moving to done:

- [ ] NetworkRecommendation model for cross-site promotions
- [ ] Boost marketplace where publishers opt-in to be recommended
- [ ] CPC/CPA pricing for recommendations (configurable per site)
- [ ] Recommendation widgets for tenant sites ("Other sites you might like")
- [ ] Enhanced curated.cx hub with personalized site discovery
- [ ] Conversion tracking (click to subscribe)
- [ ] Publisher earnings dashboard
- [ ] Network-wide content feed improvements
- [ ] Tests written and passing
- [ ] Quality gates pass
- [ ] Changes committed with task reference

---

## Plan

Step-by-step implementation approach:

1. **Step 1**: Create NetworkBoost model
   - Files: `app/models/network_boost.rb`, `db/migrate/xxx_create_network_boosts.rb`
   - Actions: source_site_id, target_site_id, cpc_rate, enabled, settings

2. **Step 2**: Create BoostImpression and BoostClick models
   - Files: Track impressions and clicks for attribution

3. **Step 3**: Create boost marketplace admin
   - Files: `app/controllers/admin/network_boosts_controller.rb`
   - Actions: Opt-in/out, set rates, view stats

4. **Step 4**: Create recommendation widgets
   - Files: `app/components/network_recommendation_component.rb`
   - Actions: Display recommended sites with tracking

5. **Step 5**: Enhance hub discovery
   - Files: Update curated.cx homepage
   - Actions: Personalized site suggestions, trending sites, new sites

6. **Step 6**: Create earnings dashboard
   - Files: `app/controllers/admin/boost_earnings_controller.rb`
   - Actions: Show earnings, pending payouts, conversion stats

7. **Step 7**: Integrate with Stripe for payouts
   - Files: Extend existing Stripe integration
   - Actions: Monthly payout calculation, Stripe Connect (future)

8. **Step 8**: Write tests
   - Files: `spec/models/network_boost_spec.rb`
   - Coverage: Impression tracking, click attribution, earnings calculation

---

## Work Log

_No work started yet._

---

## Testing Evidence

_No tests run yet._

---

## Notes

- This leverages Curated's unique multi-tenant architecture
- Start with manual payouts, add Stripe Connect later
- Consider quality controls (spam sites, inappropriate content)
- Use existing NetworkFeedService as foundation
- Hub improvements can be done incrementally

---

## Links

- Research: beehiiv Boosts, Ghost networked publishing
- Related: NetworkFeedService, TenantResolver, existing Stripe integration
