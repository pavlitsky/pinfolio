import { Controller } from "@hotwired/stimulus"

// Scrolls the page back to the top after the form submits successfully, e.g. to show a post
// the idea form just prepended to the list. Failed submissions leave the scroll alone.
// Usage: <form data-controller="scroll-top" data-action="turbo:submit-end->scroll-top#scroll">
export default class extends Controller {
  scroll(event) {
    if (!event.detail.success) return

    const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    window.scrollTo({ top: 0, behavior: reduceMotion ? "auto" : "smooth" })
  }
}
