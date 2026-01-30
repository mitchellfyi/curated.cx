import { Controller } from '@hotwired/stimulus';
import '@mux/mux-player';

/**
 * Live stream controller for Mux video player integration.
 *
 * Handles:
 * - Viewer join/leave tracking
 * - Page visibility handling (pause tracking when tab is hidden)
 */
export default class extends Controller {
  static values = {
    playbackId: String,
    joinUrl: String,
    leaveUrl: String,
  };

  connect() {
    this.joined = false;
    this.handleVisibilityChange = this.handleVisibilityChange.bind(this);

    // Track viewer join when they start watching
    if (this.hasJoinUrlValue) {
      this.joinStream();
    }

    // Handle page visibility changes
    document.addEventListener('visibilitychange', this.handleVisibilityChange);

    // Handle page unload
    window.addEventListener('beforeunload', () => this.leaveStream());
  }

  disconnect() {
    document.removeEventListener(
      'visibilitychange',
      this.handleVisibilityChange
    );
    this.leaveStream();
  }

  handleVisibilityChange() {
    if (document.hidden && this.joined) {
      this.leaveStream();
    } else if (!document.hidden && !this.joined) {
      this.joinStream();
    }
  }

  async joinStream() {
    if (!this.hasJoinUrlValue || this.joined) return;

    try {
      const response = await fetch(this.joinUrlValue, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken,
        },
      });

      if (response.ok) {
        this.joined = true;
      }
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error('Failed to join stream:', error);
    }
  }

  async leaveStream() {
    if (!this.hasLeaveUrlValue || !this.joined) return;

    try {
      // Use sendBeacon for reliability during page unload
      const data = new FormData();
      data.append('authenticity_token', this.csrfToken);

      if (navigator.sendBeacon) {
        navigator.sendBeacon(this.leaveUrlValue, data);
      } else {
        await fetch(this.leaveUrlValue, {
          method: 'POST',
          body: data,
          keepalive: true,
        });
      }

      this.joined = false;
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error('Failed to leave stream:', error);
    }
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || '';
  }
}
