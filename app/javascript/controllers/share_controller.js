import { Controller } from "@hotwired/stimulus"

// Handles social sharing functionality including copy-to-clipboard
// and native Web Share API support
export default class extends Controller {
  static targets = ["icon", "nativeButton"]
  static values = {
    url: String,
    title: String,
    text: String
  }

  connect() {
    // Show native share button if Web Share API is supported
    if (navigator.share && this.hasNativeButtonTarget) {
      this.nativeButtonTarget.classList.remove("hidden")
      this.nativeButtonTarget.classList.add("inline-flex")
    }
  }

  async copyLink(event) {
    const button = event.currentTarget
    const url = button.dataset.shareUrlValue || this.urlValue || window.location.href

    try {
      await navigator.clipboard.writeText(url)
      this.showCopiedFeedback(button)
    } catch (err) {
      // Fallback for older browsers
      this.fallbackCopyToClipboard(url)
      this.showCopiedFeedback(button)
    }
  }

  async nativeShare(event) {
    const button = event.currentTarget

    const shareData = {
      title: button.dataset.shareTitleValue || this.titleValue || document.title,
      text: button.dataset.shareTextValue || this.textValue || "",
      url: button.dataset.shareUrlValue || this.urlValue || window.location.href
    }

    try {
      await navigator.share(shareData)
    } catch (err) {
      // User cancelled or share failed - no action needed
      if (err.name !== "AbortError") {
        console.error("Share failed:", err)
      }
    }
  }

  showCopiedFeedback(button) {
    const originalHTML = button.innerHTML

    // Show checkmark
    button.innerHTML = `
      <svg class="w-4 h-4 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
      </svg>
    `
    button.classList.add("bg-green-100")

    // Reset after delay
    setTimeout(() => {
      button.innerHTML = originalHTML
      button.classList.remove("bg-green-100")
    }, 2000)
  }

  fallbackCopyToClipboard(text) {
    const textarea = document.createElement("textarea")
    textarea.value = text
    textarea.style.position = "fixed"
    textarea.style.left = "-9999px"
    document.body.appendChild(textarea)
    textarea.select()
    document.execCommand("copy")
    document.body.removeChild(textarea)
  }
}
