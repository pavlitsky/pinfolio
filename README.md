# Pinfolio

Pinfolio is a small mood-board app for collecting visual inspiration.

## The idea

Type an idea into the search field ("scandinavian kitchen", "brutalist posters",
"autumn wedding palette"…) and press Enter. Pinfolio creates a **post** for that idea
and goes to Pinterest in the background to collect matching images. The images
show up in the post's grid as they download, so you don't need to reload the page.

Then curate the board:

* **Preview** – click a tile to open a large preview. Use ← / → to move between
  images and Esc to close. Clicking the image opens the original pin on Pinterest.
* **Hide** – remove images you don't like with the × on a tile (or "Hide" in the
  preview). A toast with **Undo** appears. Hidden images are not deleted. They
  move to the post's "N hidden" panel, where you can restore them, and they are
  never collected for that post again.
* **Reorder** – drag tiles to rearrange the grid. The order is saved.
* **More** – the "+" tile at the end of the grid fetches the next batch of
  images. When Pinterest has no more results, it shows "No more".
* **Rename** – click a post's title to edit it in place. Enter saves, Esc cancels.
  Renaming starts a new Pinterest search for the new title.
* **Delete** – remove a whole post with the × next to its title.

Changes made in one browser tab appear in your other open tabs too.

> Pinterest search uses the unofficial JSON endpoint behind pinterest.com. It is
> undocumented and may change at any time, so Pinfolio is meant for occasional
> personal use.

## Technologies

| Area             | Technology                                                                 |
| ---------------- | -------------------------------------------------------------------------- |
| Language         | Ruby 4.0                                                                   |
| Framework        | Ruby on Rails 8.1                                                          |
| Database         | SQLite (also used by Solid Queue, Solid Cache and Solid Cable in production) |
| Front end        | Hotwire: Turbo (Drive, Frames, Streams, morphing page refreshes) and Stimulus |
| JavaScript       | Import maps (no Node build step), [SortableJS](https://sortablejs.github.io/Sortable/) for drag and drop |
| CSS              | Tailwind CSS (`tailwindcss-rails`)                                         |
| Assets           | Propshaft                                                                  |
| Images           | Active Storage with `image_processing` / libvips for variants and HEIC→JPEG conversion |
| Background jobs  | Active Job (Solid Queue in production)                                     |
| Real-time        | Action Cable (Solid Cable in production)                                   |
| Web server       | Puma + Thruster                                                            |
| Deployment       | Docker + Kamal                                                             |
| Tests            | RSpec, FactoryBot, WebMock                                                 |
| Code quality     | RuboCop (rails-omakase), Brakeman, bundler-audit                           |

## How it works

### Domain

* `Post` (`app/models/post.rb`) – one idea. It has a title, the Pinterest pagination
  bookmark, and `pins_requested_at`, which drives the "+" tile's loading spinner.
  `reorder_items!` saves a new drag-and-drop order.
* `Item` (`app/models/item.rb`) – one collected pin: its Pinterest URL, a grid
  `position`, a `hidden_at` timestamp (soft hide) and an attached `image` with
  preprocessed `:tile` (400×400) and `:preview` (≤1600px) variants.

### Services and jobs

* `PinterestSearch` (`app/services/pinterest_search.rb`) – fetches one page of pin
  results and returns `Data` value objects (`Result`, `Page`).
* `WebImage` (`app/services/web_image.rb`) – keeps browser-friendly formats as they
  are and converts anything else (e.g. HEIC) to JPEG with libvips.
* `CollectPinsJob` – pages through the search starting from the post's bookmark,
  creates up to 10 new items and skips URLs the post already has (hidden ones
  included). It enqueues one `AttachImageJob` per item.
* `AttachImageJob` – downloads the image, checks its type and size, runs it through
  `WebImage` and attaches it with Active Storage.

### Hotwire: live updates without custom JavaScript

The background jobs never render HTML themselves. Updates reach the browser through
**Turbo 8 page refreshes with morphing**:

* `Post` declares `broadcasts_refreshes`, and `Item` uses `belongs_to :post, touch: true`.
  So attaching an image touches the item, the item touches its post, and the post
  broadcasts a refresh over Action Cable.
* Each post card subscribes with `turbo_stream_from post` (`posts/_entry.html.erb`).
  The index subscribes with `turbo_stream_from "posts"` to pick up posts created
  in other tabs.
* The layout sets `turbo_refresh_method_tag :morph` and
  `turbo_refresh_scroll_tag :preserve`. A refresh re-fetches the page and morphs
  the DOM in place, keeping your scroll position.
* Elements that hold local UI state are protected from the morph:
  `data-turbo-permanent` on the preview dialog, the toast container and the hidden
  panel, plus the `morph-skip`, `inline-edit` and `toggle` Stimulus controllers
  (see below).

### Turbo Streams, by controller

Each controller action answers both `turbo_stream` and `html`, so the app also
works without JavaScript.

| Controller / action           | Turbo Stream response                                             | What the user sees |
| ----------------------------- | ----------------------------------------------------------------- | ------------------ |
| `PostsController#create`      | `create.turbo_stream.erb`: `replace` the idea form with an empty one, `prepend` the new post to `#posts` | The new post appears at the top and the search field is cleared |
| `PostsController#create` (invalid) | inline `turbo_stream.replace "idea_form"` with errors, status 422 | Validation message under the search field |
| `PostsController#destroy`     | `destroy.turbo_stream.erb`: `remove` the post entry               | The post card slides out (animated by `removal`) |
| `ItemsController#hide`        | `hide.turbo_stream.erb`: `remove` the tile, `append` it to the hidden grid, `replace` the hidden count, `append` an Undo toast to `#toasts` | The tile shrinks away and the "Image hidden · Undo" toast appears |
| `ItemsController#unhide`      | `unhide.turbo_stream.erb`: `remove` the toast and the hidden tile, `replace` the grid and the hidden count | The image returns to its original spot |
| `Posts::PinsController#create` | `pins/create.turbo_stream.erb`: `replace` the "+" tile with a spinner | Loading state until `CollectPinsJob` finishes and a refresh shows the new images |

### Turbo Frames, by controller

| Frame                          | Controller                         | Purpose |
| ------------------------------ | ---------------------------------- | ------- |
| `modal` (in the layout's `<dialog>`) | `ItemsController#show`       | Tiles link with `data-turbo-frame="modal"`, so the large preview with previous/next links loads into the dialog. Opened outside a frame (e.g. in a new tab), `show` redirects to the pin on Pinterest (`turbo_frame_request?`). |
| `post_N_title`                 | `Posts::TitlesController#show/edit/update` | In-place title editing: the title link loads the edit form into the same frame, and a save redirects back to `show`. |
| `post_N_hidden_items` (`loading: :lazy`) | `Posts::HiddenItemsController#index` | The hidden-images panel is fetched only the first time it is opened. |

`Posts::ItemOrdersController#update` is neither: it receives the new `item_ids[]`
order via `fetch` from the `sortable` Stimulus controller and returns `204 No Content`.

### Stimulus controllers

All controllers live in `app/javascript/controllers/` and are loaded via import maps.

| Controller    | Used in                                        | What it does |
| ------------- | ---------------------------------------------- | ------------ |
| `modal`       | `layouts/application.html.erb`, `items/show`   | Wraps the `<dialog>`: opens it on `turbo:frame-load`, clears the frame on close, closes on backdrop click, handles ←/→ keys, and after "Hide" moves on to a neighbouring image (`turbo:submit-end`). |
| `sortable`    | `posts/_grid.html.erb`                         | Drag-and-drop with SortableJS. Sends the new order to `Posts::ItemOrdersController` and restores the old order if the request fails. |
| `removal`     | post entries, image tiles, hidden tiles, toasts | Hooks into `turbo:before-stream-render` to animate an element out (collapse or shrink) before a Turbo Stream `remove` applies. Respects `prefers-reduced-motion`. |
| `toast`       | `items/_hidden_toast.html.erb`                 | Slides the Undo toast in, dismisses it after 5 seconds, and pauses the countdown on hover or focus. |
| `toggle`      | `posts/_post.html.erb`, `posts/_hidden_count.html.erb` | Shows and hides the hidden-images panel. Keeps `aria-expanded` in sync when Turbo Streams re-render the button and when morphing would reset it (`turbo:before-morph-attribute`). |
| `inline-edit` | `posts/titles/edit.html.erb`                   | Focuses the title input. Enter saves, Esc cancels, blur saves only if the value changed. Marks the frame `data-turbo-permanent` while editing so a refresh doesn't discard what you typed. |
| `morph-skip`  | `posts/_idea_form.html.erb`                    | Cancels `turbo:before-morph-element` for the search form so refreshes don't wipe what you're typing, while Turbo Streams can still replace it. |

### Other Rails features

* Nested singular resources (`resource :title`, `resource :pins`, `resource :item_order`)
  under `posts`, so each controller stays small and RESTful.
* `params.expect` for strong parameters.
* `Data.define` value objects in the services.
* Database constraints (`null: false`, foreign keys, a unique index on
  `[post_id, url]`) alongside model validations.
* `allow_browser versions: :modern` and `stale_when_importmap_changes` in
  `ApplicationController`.

## Getting started

Requirements: Ruby 4.0.5 and libvips (`brew install vips` on macOS).

```sh
bin/setup          # install gems, prepare the database and start the server
bin/dev            # Rails server + Tailwind watcher (Procfile.dev)
```

Open http://localhost:3000.

In development, jobs run in-process (Active Job async adapter) and Action Cable uses
the async adapter, so no extra processes are needed.

## Tests and linting

```sh
bin/rspec          # model, request, job and service specs (HTTP is stubbed with WebMock)
bin/rubocop        # lint
bin/brakeman       # security scan
```
