import { Controller } from "@hotwired/stimulus"

// Opens a hint panel on click or tap (on devices with a mouse, CSS also shows it on hover)
// and closes it on a click outside or Esc. The open state is a data-open attribute on the
// element, so the panel can be styled with group-data-open:.
// Usage: <div class="group" data-controller="hint" data-action="click@window->hint#closeOnClickOutside keydown.esc@window->hint#close">
//          <button data-hint-target="button" data-action="hint#toggle" aria-expanded="false">…</button>
//          <div class="invisible group-hover:visible group-data-open:visible">…</div>
export default class extends Controller {
  static targets = ["button"]

  toggle() {
    this.#set(!this.element.hasAttribute("data-open"))
  }

  close() {
    this.#set(false)
  }

  closeOnClickOutside(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  #set(open) {
    this.element.toggleAttribute("data-open", open)
    this.buttonTarget.setAttribute("aria-expanded", String(open))
  }
}
