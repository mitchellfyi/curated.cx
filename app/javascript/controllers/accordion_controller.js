import { Controller } from "@hotwired/stimulus"

// Accordion controller for FAQ sections
// Handles expand/collapse of accordion items
export default class extends Controller {
  static targets = ["trigger", "content", "icon"]

  toggle(event) {
    const trigger = event.currentTarget
    const index = this.triggerTargets.indexOf(trigger)
    const content = this.contentTargets[index]
    const icon = this.iconTargets[index]

    if (!content) return

    const isExpanded = trigger.getAttribute("aria-expanded") === "true"

    if (isExpanded) {
      this.collapse(trigger, content, icon)
    } else {
      this.expand(trigger, content, icon)
    }
  }

  expand(trigger, content, icon) {
    trigger.setAttribute("aria-expanded", "true")
    content.classList.remove("hidden")
    if (icon) {
      icon.classList.add("rotate-180")
    }
  }

  collapse(trigger, content, icon) {
    trigger.setAttribute("aria-expanded", "false")
    content.classList.add("hidden")
    if (icon) {
      icon.classList.remove("rotate-180")
    }
  }
}
