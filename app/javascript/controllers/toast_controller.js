import { Controller } from "@hotwired/stimulus"

// A temporary notification that slides in and dismisses itself after a timeout.
// Hovering or focusing it pauses the countdown so its actions (e.g. Undo) stay reachable.
// Usage: <div data-controller="toast" data-action="mouseenter->toast#pause mouseleave->toast#resume">
export default class extends Controller {
  static values = { timeout: { type: Number, default: 5000 } }

  connect() {
    this.remaining = this.timeoutValue
    this.#animate([{ opacity: 0, transform: "translateY(1rem)" }, { opacity: 1, transform: "none" }], "ease-out")
    this.resume()
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  pause() {
    if (!this.timer) return

    clearTimeout(this.timer)
    this.timer = null
    this.remaining -= Date.now() - this.startedAt
  }

  resume() {
    if (this.timer) return

    this.startedAt = Date.now()
    this.timer = setTimeout(() => this.dismiss(), Math.max(this.remaining, 0))
  }

  async dismiss() {
    this.pause()
    await this.#animate([{ opacity: 1, transform: "none" }, { opacity: 0, transform: "translateY(1rem)" }], "ease-in")
    this.element.remove()
  }

  #animate(keyframes, easing) {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return Promise.resolve()

    return this.element.animate(keyframes, { duration: 200, easing, fill: "forwards" }).finished
  }
}
