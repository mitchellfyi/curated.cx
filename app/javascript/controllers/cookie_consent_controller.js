import { Controller } from '@hotwired/stimulus';

// Cookie consent controller for GDPR compliance.
// Manages user consent for analytics tracking.
//
// Usage:
//   <div data-controller="cookie-consent"
//        data-cookie-consent-measurement-id-value="G-XXXXXXXXXX">
//     ...consent banner...
//   </div>
export default class extends Controller {
  static targets = ['banner', 'acceptButton', 'rejectButton'];
  static values = {
    measurementId: String,
    consentKey: { type: String, default: 'analytics_consent' },
  };

  connect() {
    // Check if user has already made a choice
    const consent = this.getConsent();

    if (consent === null) {
      // No choice made yet, show banner
      this.showBanner();
    } else if (consent === true) {
      // User accepted, initialize analytics
      this.initializeAnalytics();
    }
    // If consent === false, do nothing (user rejected)
  }

  accept(event) {
    event.preventDefault();
    this.setConsent(true);
    this.hideBanner();
    this.initializeAnalytics();
  }

  reject(event) {
    event.preventDefault();
    this.setConsent(false);
    this.hideBanner();
    this.disableAnalytics();
  }

  // Show consent banner
  showBanner() {
    if (this.hasBannerTarget) {
      this.bannerTarget.classList.remove('hidden');
    }
  }

  // Hide consent banner
  hideBanner() {
    if (this.hasBannerTarget) {
      this.bannerTarget.classList.add('hidden');
    }
  }

  // Store consent preference
  setConsent(value) {
    try {
      localStorage.setItem(
        this.consentKeyValue,
        JSON.stringify({
          value: value,
          timestamp: new Date().toISOString(),
        })
      );
    } catch {
      // localStorage might not be available
      this.setCookie(this.consentKeyValue, value ? '1' : '0', 365);
    }
  }

  // Get stored consent preference
  getConsent() {
    try {
      const stored = localStorage.getItem(this.consentKeyValue);
      if (stored) {
        const data = JSON.parse(stored);
        return data.value;
      }
    } catch {
      // Fall back to cookie
      const cookie = this.getCookie(this.consentKeyValue);
      if (cookie === '1') return true;
      if (cookie === '0') return false;
    }
    return null;
  }

  // Initialize Google Analytics
  initializeAnalytics() {
    if (!this.hasMeasurementIdValue || !this.measurementIdValue) return;
    if (typeof window.gtag !== 'function') return;

    // Update consent mode to granted
    window.gtag('consent', 'update', {
      analytics_storage: 'granted',
    });
  }

  // Disable analytics
  disableAnalytics() {
    if (typeof window.gtag !== 'function') return;

    // Update consent mode to denied
    window.gtag('consent', 'update', {
      analytics_storage: 'denied',
    });
  }

  // Cookie helpers
  setCookie(name, value, days) {
    const expires = new Date(Date.now() + days * 864e5).toUTCString();
    document.cookie = `${name}=${encodeURIComponent(value)}; expires=${expires}; path=/; SameSite=Lax`;
  }

  getCookie(name) {
    const value = `; ${document.cookie}`;
    const parts = value.split(`; ${name}=`);
    if (parts.length === 2) {
      return decodeURIComponent(parts.pop().split(';').shift());
    }
    return null;
  }
}
