# Analytics

This document describes the analytics implementation in Curated.cx, including Google Analytics 4 integration and GDPR-compliant cookie consent.

---

## Overview

Curated.cx supports site-level Google Analytics 4 (GA4) integration with:

1. **GDPR-compliant cookie consent** - Consent before tracking
2. **GA4 Consent Mode** - Privacy-first by default
3. **Event tracking** - Share, vote, and search events
4. **LocalStorage persistence** - Remember user consent

---

## Configuration

Analytics is configured per-site via the `config` JSONB field:

```ruby
site.ga_measurement_id  # => "G-XXXXXXXXXX" or nil
site.analytics_enabled? # => true/false
```

### Setting the Measurement ID

In the site config:

```json
{
  "analytics": {
    "ga_measurement_id": "G-XXXXXXXXXX"
  }
}
```

When no measurement ID is set, no analytics scripts are loaded.

---

## GDPR Consent Mode

The implementation follows GA4 Consent Mode v2:

### Default State (No Consent)

```javascript
gtag('consent', 'default', {
  'analytics_storage': 'denied',
  'ad_storage': 'denied',
  'ad_user_data': 'denied',
  'ad_personalization': 'denied',
  'wait_for_update': 500
});
```

### After Consent Granted

```javascript
gtag('consent', 'update', {
  'analytics_storage': 'granted'
});
```

This ensures:
- No cookies until explicit consent
- Basic analytics (cookieless) still works
- Full tracking after consent

---

## Cookie Consent Banner

### UI Components

- **Banner**: Bottom-fixed, dismissible consent request
- **Buttons**: Accept / Reject options
- **Styling**: Tailwind CSS, dark mode support

### Stimulus Controller

`analytics_controller.js` handles:

- Showing/hiding consent banner
- Storing consent in localStorage
- Updating GA consent mode
- Hiding banner on preference pages

### LocalStorage Keys

| Key | Values | Description |
|-----|--------|-------------|
| `analytics_consent` | `granted`, `denied` | User's consent choice |

---

## Event Tracking

Custom events are tracked for key user interactions:

### Share Events

Triggered when users share content:

```javascript
gtag('event', 'share', {
  method: 'twitter',     // twitter, facebook, linkedin, copy
  content_type: 'link',
  item_id: 'content_123'
});
```

### Vote Events

Triggered when users vote on content:

```javascript
gtag('event', 'vote', {
  content_type: 'content_item',
  item_id: '123',
  value: 1  // 1 for upvote
});
```

### Search Events

Triggered when users search:

```javascript
gtag('event', 'search', {
  search_term: 'rails tutorial'
});
```

---

## Files

| File | Purpose |
|------|---------|
| `app/helpers/analytics_helper.rb` | Helper methods for views |
| `app/javascript/controllers/analytics_controller.js` | Consent/tracking |
| `app/javascript/controllers/cookie_consent_controller.js` | Banner UI |
| `app/views/shared/analytics/_ga4.html.erb` | GA4 script partial |
| `app/views/shared/analytics/_cookie_consent.html.erb` | Banner partial |

---

## Integration

### Layout Integration

In `application.html.erb`:

```erb
<%= render 'shared/analytics/ga4' if analytics_enabled? %>
<%= render 'shared/analytics/cookie_consent' if analytics_enabled? %>
```

### Helper Methods

```ruby
# Check if analytics is enabled for current site
analytics_enabled?  # => true/false

# Get measurement ID
ga_measurement_id   # => "G-XXXXXXXXXX"
```

---

## Privacy Features

1. **Consent-first**: No tracking cookies until explicit opt-in
2. **Respect "Do Not Track"**: Future enhancement
3. **Data minimization**: Only essential events tracked
4. **Transparent**: Clear consent UI with links to learn more

---

## Testing

```ruby
# In feature specs
expect(page).to have_css('[data-controller="cookie-consent"]')
click_button 'Accept'
expect(page).not_to have_css('[data-controller="cookie-consent"]')
```

---

## Future Enhancements

- Server-side analytics (privacy-friendly alternative)
- Custom event dashboard in admin
- A/B testing integration
- Privacy-focused alternatives (Plausible, Fathom)

---

*Last Updated: 2026-01-30*
