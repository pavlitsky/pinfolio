import { Controller } from "@hotwired/stimulus"

// An inline edit form inside a Turbo Frame: focuses the input on open,
// Enter saves, Esc cancels (follows the cancel link), and leaving the field
// saves if the value changed or cancels if it didn't.
// Usage: <form data-controller="inline-edit" data-action="submit->inline-edit#submitting keydown.esc->inline-edit#cancel">
//          <input data-inline-edit-target="input" data-action="blur->inline-edit#commit">
//          <a href="…" data-inline-edit-target="cancel">Cancel</a>
export default class extends Controller {
  static targets = ["input", "cancel"]

  connect() {
    // Keep the open editor (and what's typed) when a page refresh morphs the page
    this.frame = this.element.closest("turbo-frame")
    this.frame?.setAttribute("data-turbo-permanent", "")

    this.originalValue = this.inputTarget.value
    this.inputTarget.focus()
    this.inputTarget.select()
  }

  disconnect() {
    this.frame?.removeAttribute("data-turbo-permanent")
  }

  submitting() {
    this.done = true
  }

  cancel(event) {
    event?.preventDefault()
    if (this.done) return

    this.done = true
    this.cancelTarget.click()
  }

  commit() {
    if (this.done) return

    this.inputTarget.value.trim() === this.originalValue.trim() ? this.cancel() : this.element.requestSubmit()
  }
}
