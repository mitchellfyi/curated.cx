import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  async copyLink(event) {
    const button = event.currentTarget
    const url = button.dataset.url

    try {
      await navigator.clipboard.writeText(url)
      
      // Show success feedback
      const originalTitle = button.getAttribute('title')
      button.setAttribute('title', 'Copied!')
      button.classList.add('bg-green-100', 'text-green-600')
      button.classList.remove('bg-gray-100', 'text-gray-600')
      
      // Reset after 2 seconds
      setTimeout(() => {
        button.setAttribute('title', originalTitle)
        button.classList.remove('bg-green-100', 'text-green-600')
        button.classList.add('bg-gray-100', 'text-gray-600')
      }, 2000)
    } catch (err) {
      console.error('Failed to copy link:', err)
    }
  }
}
