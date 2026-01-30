# Task: Newsletter Subscriber Referral Program

## Metadata

| Field       | Value                                                  |
| ----------- | ------------------------------------------------------ |
| ID          | `002-001-newsletter-subscriber-referral-program`       |
| Status      | `todo`                                                 |
| Priority    | `002` High                                             |
| Created     | `2026-01-30 15:30`                                     |
| Started     |                                                        |
| Completed   |                                                        |
| Blocked By  |                                                        |
| Blocks      |                                                        |
| Assigned To | `worker-1` |
| Assigned At | `2026-01-30 15:04` |

---

## Context

Why does this task exist? What problem does it solve?

- **Competitive Gap**: beehiiv's referral program accounts for 5-10% of their growth. Morning Brew grew from 100k to 1.5M subscribers in 18 months using referrals. The Hustle credits 10% of their free list growth to referrals with 10,000+ ambassadors.
- **User Value**: Curated already has DigestSubscription for email digests but no mechanism for organic growth through subscriber advocacy.
- **Monetization Potential**: Referral programs increase subscriber lifetime value and reduce customer acquisition costs.
- **RICE Score**: 270 (Reach: 1000, Impact: 3, Confidence: 90%, Effort: 1 person-week)

**Problem**: Publishers have no automated way to grow their subscriber base through existing subscribers. All growth requires manual effort or paid acquisition.

**Solution**: A milestone-based referral system where subscribers earn rewards for referring new subscribers. Focus on a simple "1 referral = digital reward" model as traditional milestone programs have declining effectiveness.

---

## Acceptance Criteria

All must be checked before moving to done:

- [ ] Referral model with unique referral codes per subscriber
- [ ] Referral tracking (who referred whom)
- [ ] Referral attribution on new subscriber signup
- [ ] Configurable reward tiers per site (e.g., 1 referral = download, 5 = featured, etc.)
- [ ] Referral dashboard for subscribers showing their stats
- [ ] Publisher dashboard showing referral metrics
- [ ] Email notifications for referral milestones
- [ ] Referral share widgets (copy link, social share buttons)
- [ ] Tests written and passing
- [ ] Quality gates pass
- [ ] Changes committed with task reference

---

## Plan

Step-by-step implementation approach:

1. **Step 1**: Create Referral model
   - Files: `app/models/referral.rb`, `db/migrate/xxx_create_referrals.rb`
   - Actions: Create model with referee_id, referrer_id, site_id, status, rewarded_at

2. **Step 2**: Add referral_code to DigestSubscription
   - Files: `db/migrate/xxx_add_referral_code_to_digest_subscriptions.rb`
   - Actions: Add unique referral code generation on subscription creation

3. **Step 3**: Create ReferralReward model
   - Files: `app/models/referral_reward.rb`
   - Actions: Configurable rewards per milestone per site

4. **Step 4**: Update subscription flow
   - Files: `app/controllers/digest_subscriptions_controller.rb`
   - Actions: Track referral_code on signup, create Referral record

5. **Step 5**: Create referral dashboard for subscribers
   - Files: `app/controllers/referrals_controller.rb`, `app/views/referrals/`
   - Actions: Show referral stats, share widgets, earned rewards

6. **Step 6**: Create admin referral reporting
   - Files: `app/controllers/admin/referrals_controller.rb`
   - Actions: Show referral metrics, top referrers, conversion rates

7. **Step 7**: Write tests
   - Files: `spec/models/referral_spec.rb`, `spec/features/referral_spec.rb`
   - Coverage: Referral creation, attribution, reward eligibility

---

## Work Log

_No work started yet._

---

## Testing Evidence

_No tests run yet._

---

## Notes

- Consider integration with existing email digest system for referral milestone emails
- Avoid overly complex milestone systems - research shows simple "1 referral = reward" works best in 2026
- Ensure referral codes are URL-safe and memorable
- Consider fraud prevention (same IP, disposable emails)

---

## Links

- Research: beehiiv referral program, Morning Brew growth strategy
- Related: DigestSubscription model, email digest system
