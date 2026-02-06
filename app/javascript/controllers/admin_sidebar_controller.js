import { Controller } from '@hotwired/stimulus';

// Admin sidebar toggle for mobile/tablet
// Shows sidebar as a slide-in drawer on small screens
export default class extends Controller {
  static targets = ['sidebar', 'overlay', 'content'];

  connect() {
    this.handleResize = this.handleResize.bind(this);
    window.addEventListener('resize', this.handleResize);
  }

  disconnect() {
    window.removeEventListener('resize', this.handleResize);
  }

  toggle() {
    const isOpen = !this.sidebarTarget.classList.contains('-translate-x-full');
    if (isOpen) {
      this.close();
    } else {
      this.open();
    }
  }

  open() {
    this.sidebarTarget.classList.remove('-translate-x-full');
    this.overlayTarget.classList.remove('hidden');
    document.body.classList.add('overflow-hidden', 'lg:overflow-auto');
  }

  close() {
    this.sidebarTarget.classList.add('-translate-x-full');
    this.overlayTarget.classList.add('hidden');
    document.body.classList.remove('overflow-hidden', 'lg:overflow-auto');
  }

  handleResize() {
    // Auto-close drawer when resizing to desktop
    if (window.innerWidth >= 1024) {
      this.sidebarTarget.classList.remove('-translate-x-full');
      this.overlayTarget.classList.add('hidden');
      document.body.classList.remove('overflow-hidden', 'lg:overflow-auto');
    } else if (
      !this.sidebarTarget.classList.contains('-translate-x-full') &&
      this.overlayTarget.classList.contains('hidden')
    ) {
      // If sidebar is visible but overlay hidden (was desktop), hide sidebar on mobile
      this.sidebarTarget.classList.add('-translate-x-full');
    }
  }
}
