import { Controller } from "@hotwired/stimulus"

// Sets data-scrolled on the element while the page is scrolled away from the top, so a
// sticky header can be styled with data-scrolled: and group-data-scrolled:. Rechecks after
// a morph refresh, which resets the attribute to the server-rendered markup.
// Usage: <header class="group" data-controller="scrolled"
//                data-action="scroll@window->scrolled#update:passive turbo:morph@document->scrolled#update">
export default class extends Controller {
  connect() {
    this.update()
  }

  update() {
    this.element.toggleAttribute("data-scrolled", window.scrollY > 0)
  }
}
