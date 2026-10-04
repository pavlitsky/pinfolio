import { Controller } from "@hotwired/stimulus"

// Shows and hides a panel. The button may be re-rendered by Turbo Streams,
// so its aria-expanded state is synced whenever it (re)connects.
// Usage: <div data-controller="toggle">
//          <button data-toggle-target="button" data-action="toggle#toggle">…</button>
//          <div data-toggle-target="panel" hidden>…</div>
export default class extends Controller {
  static targets = ["button", "panel"]

  toggle() {
    this.panelTarget.hidden = !this.panelTarget.hidden
    this.buttonTargets.forEach((button) => this.#sync(button))
  }

  buttonTargetConnected(button) {
    this.#sync(button)
  }

  #sync(button) {
    button.setAttribute("aria-expanded", String(!this.panelTarget.hidden))
  }
}
