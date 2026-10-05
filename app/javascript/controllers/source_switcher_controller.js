import { Controller } from "@hotwired/stimulus"

// Remembers the source chosen in the idea form's switcher in a cookie, so the server
// preselects it after a reload (see PostsController#remembered_source).
// Usage: <fieldset data-controller="source-switcher" data-action="change->source-switcher#remember">
export default class extends Controller {
  remember(event) {
    document.cookie = `post_source=${encodeURIComponent(event.target.value)}; path=/; max-age=31536000; samesite=lax`
  }
}
