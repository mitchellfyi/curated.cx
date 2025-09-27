import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this.closeOnClickOutside = this.closeOnClickOutside.bind(this)
    document.addEventListener("click", this.closeOnClickOutside)
  }

  disconnect() {
    document.removeEventListener("click", this.closeOnClickOutside)
  }

  toggle(event) {
    event.stopPropagation()
    this.menuTarget.classList.toggle("hidden")
    
    // Update aria-expanded
    const button = event.currentTarget
    const isExpanded = !this.menuTarget.classList.contains("hidden")
    button.setAttribute("aria-expanded", isExpanded)
  }

  closeOnClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  close() {
    this.menuTarget.classList.add("hidden")
    const button = this.element.querySelector('[aria-expanded]')
    if (button) {
      button.setAttribute("aria-expanded", "false")
    }
  }
}
