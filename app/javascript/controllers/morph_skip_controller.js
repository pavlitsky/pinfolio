import { Controller } from "@hotwired/stimulus"

// Leaves the element (and what's typed in it) untouched when a page refresh morphs the page.
// Unlike data-turbo-permanent, Turbo Streams can still replace it, e.g. to reset a form.
// Usage: <form data-controller="morph-skip" data-action="turbo:before-morph-element->morph-skip#skip">
export default class extends Controller {
  skip(event) {
    if (event.target === this.element) event.preventDefault()
  }
}
