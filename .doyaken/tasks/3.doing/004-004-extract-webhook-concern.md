# Task: Extract Webhook Controller Concern

## Metadata

| Field       | Value                             |
| ----------- | --------------------------------- |
| ID          | `004-004-extract-webhook-concern` |
| Status      | `todo`                            |
| Priority    | `003` Medium                      |
| Created     | `2026-02-01 19:20`                |
| Labels      | `technical-debt`, `refactor`      |

---

## Context

Similar webhook verification patterns found in:
- `MuxWebhooksController` line 36
- `StripeWebhooksController` line 34

Also similar rescue handling (mass=66) at lines 21, 25, 27.

---

## Acceptance Criteria

- [ ] Create `WebhookVerifiable` concern
- [ ] Extract common signature verification pattern
- [ ] Extract common error handling
- [ ] Refactor both controllers
- [ ] Tests pass
- [ ] Quality gates pass

---

## Plan

1. **Create concern**: `app/controllers/concerns/webhook_verifiable.rb`
   - Extract signature verification pattern
   - Extract error response handling

2. **Refactor controllers**
   - Include concern
   - Override provider-specific verification

3. **Update tests**
   - Ensure webhook tests still pass

---

## Notes

- Lower priority as the duplication is smaller
- Files: `app/controllers/mux_webhooks_controller.rb:36`, `app/controllers/stripe_webhooks_controller.rb:34`

---

## Links

- Related: `app/controllers/mux_webhooks_controller.rb`
- Related: `app/controllers/stripe_webhooks_controller.rb`
