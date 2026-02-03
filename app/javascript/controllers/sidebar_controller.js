import { Controller } from '@hotwired/stimulus';

// Sidebar controller for collapsible navigation sections
// Persists open/closed state in localStorage
export default class extends Controller {
  static targets = ['section', 'content', 'icon'];
  static values = {
    key: { type: String, default: 'admin-sidebar-state' }
  };

  connect() {
    this.restoreState();
    this.highlightActiveSection();
  }

  toggle(event) {
    const section = event.currentTarget.closest('[data-sidebar-target="section"]');
    if (!section) return;

    const sectionName = section.dataset.sectionName;
    const content = section.querySelector('[data-sidebar-target="content"]');
    const icon = section.querySelector('[data-sidebar-target="icon"]');

    if (!content) return;

    const isExpanded = !content.classList.contains('hidden');

    if (isExpanded) {
      this.collapse(content, icon);
      this.saveState(sectionName, false);
    } else {
      this.expand(content, icon);
      this.saveState(sectionName, true);
    }
  }

  expand(content, icon) {
    content.classList.remove('hidden');
    if (icon) {
      icon.classList.add('rotate-180');
    }
  }

  collapse(content, icon) {
    content.classList.add('hidden');
    if (icon) {
      icon.classList.remove('rotate-180');
    }
  }

  saveState(sectionName, isOpen) {
    const state = this.getStoredState();
    state[sectionName] = isOpen;
    localStorage.setItem(this.keyValue, JSON.stringify(state));
  }

  getStoredState() {
    try {
      return JSON.parse(localStorage.getItem(this.keyValue)) || {};
    } catch {
      return {};
    }
  }

  restoreState() {
    const state = this.getStoredState();

    this.sectionTargets.forEach((section) => {
      const sectionName = section.dataset.sectionName;
      const content = section.querySelector('[data-sidebar-target="content"]');
      const icon = section.querySelector('[data-sidebar-target="icon"]');

      if (!content) return;

      // Default to collapsed unless explicitly opened or contains active link
      const shouldBeOpen = state[sectionName] === true;

      if (shouldBeOpen) {
        this.expand(content, icon);
      } else {
        this.collapse(content, icon);
      }
    });
  }

  highlightActiveSection() {
    // Auto-expand section containing active link
    const activeLink = this.element.querySelector(
      'a.bg-gray-100, a.bg-red-50, a.bg-blue-100'
    );
    if (activeLink) {
      const section = activeLink.closest('[data-sidebar-target="section"]');
      if (section) {
        const sectionName = section.dataset.sectionName;
        const content = section.querySelector('[data-sidebar-target="content"]');
        const icon = section.querySelector('[data-sidebar-target="icon"]');

        if (content && content.classList.contains('hidden')) {
          this.expand(content, icon);
          this.saveState(sectionName, true);
        }
      }
    }
  }
}
