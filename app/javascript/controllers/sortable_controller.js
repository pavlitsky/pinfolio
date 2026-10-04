import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Drag-and-drop reordering of the children marked with data-sortable-id.
// After a drop, PATCHes the ids in their new order (as item_ids[]) to urlValue;
// if the server rejects it, the previous order is restored.
// Usage: <div data-controller="sortable" data-sortable-url-value="/posts/1/item_order">
//          <div data-sortable-id="1">…</div>
export default class extends Controller {
  static values = { url: String }

  connect() {
    this.sortable = Sortable.create(this.element, {
      draggable: "[data-sortable-id]",
      dataIdAttr: "data-sortable-id",
      // Buttons inside items (e.g. hide ×) stay clickable
      filter: "form, button",
      preventOnFilter: false,
      // On touch screens a short press starts the drag, so swiping still scrolls
      delay: 200,
      delayOnTouchOnly: true,
      animation: 150,
      ghostClass: "opacity-30",
      // Keep non-sortable children (e.g. the "+" tile) after the items
      onMove: (event) => event.related.hasAttribute("data-sortable-id"),
      onStart: () => { this.previousOrder = this.sortable.toArray() },
      onEnd: (event) => { if (event.oldIndex !== event.newIndex) this.#save() }
    })
  }

  disconnect() {
    this.sortable?.destroy()
  }

  async #save() {
    const body = new FormData()
    this.sortable.toArray().forEach((id) => body.append("item_ids[]", id))

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        body,
        headers: { "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content }
      })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
    } catch (error) {
      console.error("Could not save the new order", error)
      this.sortable.sort(this.previousOrder, true)
    }
  }
}
