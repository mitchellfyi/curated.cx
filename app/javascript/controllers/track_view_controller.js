import { Controller } from '@hotwired/stimulus';

// Tracks content views when user clicks external content links.
// Fires a POST request to record the view before navigating away.
//
// Usage:
//   <a href="https://external.com"
//      data-controller="track-view"
//      data-action="click->track-view#track"
//      data-track-view-content-id-value="123">
//     Article Title
//   </a>
export default class extends Controller {
  static values = {
    contentId: Number,
  };

  track(_event) {
    if (!this.hasContentIdValue) return;

    const url = `/content_items/${this.contentIdValue}/views`;
    const csrfToken = document.querySelector(
      'meta[name="csrf-token"]'
    )?.content;

    // Use sendBeacon for reliable delivery even during page navigation
    // Falls back to fetch if sendBeacon is not available
    const data = new FormData();

    if (navigator.sendBeacon && csrfToken) {
      // sendBeacon doesn't support headers, so we add CSRF token to FormData
      data.append('authenticity_token', csrfToken);
      navigator.sendBeacon(url, data);
    } else if (csrfToken) {
      // Fallback to fetch with keepalive for older browsers
      fetch(url, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': csrfToken,
          Accept: 'application/json',
        },
        body: data,
        keepalive: true,
      }).catch(() => {
        // Silently fail - view tracking is non-critical
      });
    }
    // Allow default navigation to proceed
  }
}
