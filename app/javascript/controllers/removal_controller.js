import { Controller } from "@hotwired/stimulus"

// Animates the element out before a Turbo Stream "remove" action targeting it is applied.
// Usage: <div id="..." data-controller="removal" data-action="turbo:before-stream-render@document->removal#animate">
export default class extends Controller {
  static values = { duration: { type: Number, default: 300 } }

  animate(event) {
    const stream = event.target
    if (stream.action !== "remove" || stream.target !== this.element.id) return

    const render = event.detail.render
    event.detail.render = async (streamElement) => {
      await this.#animateOut()
      render(streamElement)
    }
  }

  async #animateOut() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return

    const { height, paddingBottom, marginTop, marginBottom } = getComputedStyle(this.element)
    const expanded = { height, paddingBottom, marginTop, marginBottom }
    const collapsed = { height: "0px", paddingBottom: "0px", marginTop: "0px", marginBottom: "0px" }
    this.element.style.overflow = "hidden"
    this.element.style.pointerEvents = "none"

    // Slide and fade out first, then close the gap left behind
    await this.element.animate([
      { opacity: 1, transform: "translateX(0)", ...expanded },
      { opacity: 0, transform: "translateX(1.5rem)", ...expanded, offset: 0.5 },
      { opacity: 0, transform: "translateX(1.5rem)", ...collapsed }
    ], { duration: this.durationValue, easing: "ease-in-out", fill: "forwards" }).finished
  }
}
