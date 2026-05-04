import { Controller } from "@hotwired/stimulus"

// Auto-dismisses a flash banner after a delay; also handles manual dismiss
// via a click target. Wire via `data-controller="flash"` on the banner.
export default class extends Controller {
  static values = { delay: { type: Number, default: 4500 } }

  connect() {
    this.timer = setTimeout(() => this.dismiss(), this.delayValue)
  }

  disconnect() {
    if (this.timer) clearTimeout(this.timer)
  }

  dismiss() {
    if (this.timer) clearTimeout(this.timer)
    this.element.style.transition = "opacity 280ms ease, transform 280ms ease"
    this.element.style.opacity = "0"
    this.element.style.transform = "translateX(16px)"
    setTimeout(() => this.element.remove(), 280)
  }
}
