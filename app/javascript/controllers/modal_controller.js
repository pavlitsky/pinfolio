import { Controller } from "@hotwired/stimulus"

// A <dialog> wrapping a Turbo Frame: opens when the frame loads content and
// empties the frame when closed. Arrow keys follow the previous/next links.
// Usage: <dialog data-controller="modal"
//                data-action="turbo:frame-load->modal#open close->modal#reset …">
//          <turbo-frame id="modal" data-modal-target="frame"></turbo-frame>
//        </dialog>
export default class extends Controller {
  static targets = ["frame", "previous", "next"]

  open() {
    if (this.element.open) return

    this.element.showModal()
    document.documentElement.classList.add("overflow-hidden")
  }

  close() {
    this.element.close()
  }

  // Runs on the dialog's "close" event, whichever way it was closed (Esc, button, backdrop)
  reset() {
    document.documentElement.classList.remove("overflow-hidden")
    // Dropping src lets the same item open again on the next click
    this.frameTarget.removeAttribute("src")
    this.frameTarget.innerHTML = ""
  }

  closeOnBackdrop(event) {
    if (event.target === this.element) this.close()
  }

  previous(event) {
    this.#follow(event, this.hasPreviousTarget && this.previousTarget)
  }

  next(event) {
    this.#follow(event, this.hasNextTarget && this.nextTarget)
  }

  // After the shown item is hidden, move on to a neighbour, or close if none is left
  advance(event) {
    if (!event.detail.success) return

    const neighbour = (this.hasNextTarget && this.nextTarget) || (this.hasPreviousTarget && this.previousTarget)
    neighbour ? neighbour.click() : this.close()
  }

  #follow(event, link) {
    if (!link) return

    event.preventDefault()
    link.click()
  }
}
