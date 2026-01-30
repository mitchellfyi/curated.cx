import { Controller } from '@hotwired/stimulus';

// Analytics controller for Google Analytics 4 event tracking.
// Handles click tracking, page views, and custom events.
//
// Usage:
//   <button data-controller="analytics"
//           data-action="click->analytics#track"
//           data-analytics-event-value="button_click"
//           data-analytics-params-value='{"button_name": "signup"}'>
//     Sign Up
//   </button>
export default class extends Controller {
  static values = {
    event: String,
    params: { type: Object, default: {} },
  };

  connect() {
    // Track page view if this is a pageview controller
    if (this.eventValue === 'page_view') {
      this.trackPageView();
    }
  }

  // Track a custom event
  track(_event) {
    if (!this.hasEventValue) return;
    if (!this.isGtagAvailable()) return;

    const eventName = this.eventValue;
    const params = this.paramsValue;

    this.sendEvent(eventName, params);
  }

  // Track affiliate link clicks
  trackAffiliate(event) {
    if (!this.isGtagAvailable()) return;

    const link = event.currentTarget;
    const listingId = link.dataset.listingId;
    const category = link.dataset.category || '';

    this.sendEvent('affiliate_click', {
      listing_id: listingId,
      category: category,
      link_url: link.href,
    });
  }

  // Track social share events
  trackShare(event) {
    if (!this.isGtagAvailable()) return;

    const button = event.currentTarget;
    const platform = button.dataset.platform || 'unknown';
    const contentType = button.dataset.contentType || 'page';
    const contentId = button.dataset.contentId || '';

    this.sendEvent('share', {
      method: platform,
      content_type: contentType,
      item_id: contentId,
    });
  }

  // Track voting events
  trackVote(event) {
    if (!this.isGtagAvailable()) return;

    const button = event.currentTarget;
    const contentId = button.dataset.contentId || '';
    const contentType = button.dataset.contentType || 'content_item';

    this.sendEvent('vote', {
      content_id: contentId,
      content_type: contentType,
    });
  }

  // Track search events
  trackSearch(event) {
    if (!this.isGtagAvailable()) return;

    const form = event.currentTarget;
    const searchInput = form.querySelector('input[name="q"]');
    const searchTerm = searchInput?.value || '';

    if (searchTerm.trim()) {
      this.sendEvent('search', {
        search_term: searchTerm.trim(),
      });
    }
  }

  // Track form submissions
  trackSubmission(event) {
    if (!this.isGtagAvailable()) return;

    const form = event.currentTarget;
    const formType = form.dataset.formType || 'submission';

    this.sendEvent('form_submit', {
      form_type: formType,
    });
  }

  // Track content engagement (time on page, scroll depth)
  trackEngagement(event) {
    if (!this.isGtagAvailable()) return;

    const element = event.currentTarget;
    const contentId = element.dataset.contentId || '';

    this.sendEvent('content_engagement', {
      content_id: contentId,
      engagement_type: 'scroll_50',
    });
  }

  // Private: Send event to GA4
  sendEvent(eventName, params = {}) {
    // Add common parameters
    const enrichedParams = {
      ...params,
      page_location: window.location.href,
      page_title: document.title,
    };

    window.gtag('event', eventName, enrichedParams);
  }

  // Private: Track page view
  trackPageView() {
    if (!this.isGtagAvailable()) return;

    this.sendEvent('page_view', {
      page_path: window.location.pathname,
    });
  }

  // Private: Check if gtag is available
  isGtagAvailable() {
    return typeof window.gtag === 'function';
  }
}
