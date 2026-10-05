require "rails_helper"

RSpec.describe "/posts", type: :request do
  let(:valid_attributes) { { title: "My post" } }
  let(:invalid_attributes) { { title: "" } }

  describe "GET /index" do
    it "renders a successful response" do
      create(:post)
      get posts_url
      expect(response).to be_successful
    end
  end

  describe "GET / (root)" do
    let!(:post_record) { create(:post, title: "Holiday photos") }

    def attach_image(item)
      item.image.attach(io: StringIO.new("fake image"), filename: "photo.jpg", content_type: "image/jpeg")
    end

    it "shows the idea input without a label" do
      get root_url

      input = Nokogiri::HTML(response.body).at_css("form#idea_form input[name='post[title]']")
      expect(input["placeholder"]).to eq("Search anything...")
      expect(response.body).not_to include("New post")
      expect(Nokogiri::HTML(response.body).at_css("label[for='post_title']")).to be_nil
    end

    it "shows the source switcher inside the idea form, with Pinterest selected" do
      get root_url

      form = Nokogiri::HTML(response.body).at_css("form#idea_form")
      radios = form.css("input[type=radio][name='post[source]']")
      expect(radios.map { |radio| [ radio["value"], radio.parent.text.strip ] }).to eq([ %w[pinterest Pinterest], %w[flickr Flickr] ])
      expect(radios.select { |radio| radio["checked"] }.map { |radio| radio["value"] }).to eq([ "pinterest" ])
    end

    describe "the remembered source" do
      def checked_source = Nokogiri::HTML(response.body).at_css("form#idea_form input[name='post[source]'][checked]")&.[]("value")

      it "preselects the source last chosen in the switcher" do
        cookies[:post_source] = "flickr"
        get root_url

        expect(checked_source).to eq("flickr")
      end

      it "falls back to Pinterest for an unknown source" do
        cookies[:post_source] = "instagram"
        get root_url

        expect(checked_source).to eq("pinterest")
      end
    end

    it "shows the app name linking home in the header, outside the idea form" do
      get root_url

      link = Nokogiri::HTML(response.body).at_css("a[href='/']")
      expect(link.text.strip).to eq("Pinfolio")
      expect(link.ancestors("form#idea_form")).to be_empty
    end

    it "explains the app behind a \"What's this?\" button in the header" do
      get root_url

      hint = Nokogiri::HTML(response.body).at_css("#about[data-controller='hint']")
      button = hint.at_css("button[data-action='hint#toggle']")
      expect(button.text.strip).to eq("What's this?")
      expect(button["aria-expanded"]).to eq("false")
      expect(hint.at_css("##{button['aria-controls']}").text).to include("Pinterest", "Flickr")
      expect(hint.ancestors("form#idea_form")).to be_empty
    end

    it "offers a delete (×) button in the post's title row" do
      get root_url

      entry = Nokogiri::HTML(response.body).at_css("##{ActionView::RecordIdentifier.dom_id(post_record, :entry)}")
      expect(entry["data-controller"]).to eq("removal")
      # The row holding both the title and the post's delete form
      title_row = entry.at_css("h2").ancestors("div").find { |div| div.at_css("form[action='#{post_path(post_record)}']") }
      expect(title_row.css("button").map { |button| button.text.strip }).to eq([ "×" ])
      button = title_row.at_css("form[action='#{post_path(post_record)}'] button")
      expect(button["aria-label"]).to eq("Delete post “Holiday photos”")
      expect(entry.at_css(".group\\/post")).to be_present
      expect(button["class"]).to include("opacity-0", "group-hover/post:opacity-100")
      expect(title_row.at_css("form input[name='_method']")["value"]).to eq("delete")
    end

    it "has an empty image preview dialog wired to the modal controller" do
      get root_url

      dialog = Nokogiri::HTML(response.body).at_css("dialog[data-controller='modal']")
      expect(dialog["data-action"]).to include("turbo:frame-load->modal#open", "close->modal#reset", "keydown.left->modal#previous", "keydown.right->modal#next")
      frame = dialog.at_css("turbo-frame#modal")
      expect(frame["data-modal-target"]).to eq("frame")
      expect(frame.children.to_s.strip).to be_empty
    end

    it "renders each title in its own frame, linking to the inline editor" do
      get root_url

      frame = Nokogiri::HTML(response.body).at_css("turbo-frame##{ActionView::RecordIdentifier.dom_id(post_record, :title)}")
      expect(frame.at_css("h2 a")["href"]).to eq(edit_post_title_path(post_record))
    end

    describe "page refreshes" do
      def page = Nokogiri::HTML(response.body)

      it "morphs on refresh, keeping the scroll position" do
        get root_url

        expect(page.at_css("meta[name='turbo-refresh-method']")["content"]).to eq("morph")
        expect(page.at_css("meta[name='turbo-refresh-scroll']")["content"]).to eq("preserve")
      end

      it "subscribes to new posts and to each post" do
        get root_url

        streams = page.css("turbo-cable-stream-source").map { |source| Turbo::StreamsChannel.verified_stream_name(source["signed-stream-name"]) }
        expect(streams).to include("posts", post_record.to_gid_param)
      end

      it "keeps client-side state out of morphs" do
        get root_url

        %w[#image_preview #toasts].each do |selector|
          expect(page.at_css(selector)).to have_attribute("data-turbo-permanent"), selector
        end
        # Skips morphs but isn't permanent, so streams can still replace it (clearing it after a create)
        form = page.at_css("#idea_form")
        expect(form).not_to have_attribute("data-turbo-permanent")
        expect(form["data-action"].split).to include("turbo:before-morph-element->morph-skip#skip")
        expect(page.at_css("##{ActionView::RecordIdentifier.dom_id(post_record, :hidden_panel)}")).to have_attribute("data-turbo-permanent")
        expect(page.at_css("##{ActionView::RecordIdentifier.dom_id(post_record)}")["data-action"]).to eq("turbo:before-morph-attribute->toggle#preserveState")
      end

      it "scrolls back to the top after the idea form creates a post, so the new post is in view" do
        get root_url

        form = page.at_css("#idea_form")
        expect(form["data-controller"].split).to include("scroll-top")
        expect(form["data-action"].split).to include("turbo:submit-end->scroll-top#scroll")
      end
    end

    it "renders host-relative image urls even outside a request (e.g. Turbo Stream renders)" do
      item = create(:item, post: post_record).tap { |i| attach_image(i) }

      html = ApplicationController.render(partial: "posts/post", locals: { post: post_record.reload })

      src = Nokogiri::HTML(html).at_css("##{ActionView::RecordIdentifier.dom_id(item, :image)} img")["src"]
      expect(src).to start_with("/rails/active_storage/")
    end

    it "shows tiles with the resized tile variant rather than the original" do
      item = create(:item, post: post_record).tap { |i| attach_image(i) }

      get root_url

      src = Nokogiri::HTML(response.body).at_css("##{ActionView::RecordIdentifier.dom_id(item, :image)} img")["src"]
      expect(src).to start_with("/rails/active_storage/representations/")
    end

    it "has a container for notifications such as Undo" do
      get root_url

      expect(Nokogiri::HTML(response.body).at_css("#toasts[aria-live='polite']")).to be_present
    end

    describe "hidden images" do
      def page = Nokogiri::HTML(response.body)
      def hidden_count = page.at_css("##{ActionView::RecordIdentifier.dom_id(post_record, :hidden_count)}")
      def hidden_panel = page.at_css("##{ActionView::RecordIdentifier.dom_id(post_record, :hidden_panel)}")

      context "when the post has none" do
        it "shows no hidden count button" do
          get root_url

          expect(hidden_count).to be_present
          expect(hidden_count.at_css("button")).to be_nil
        end
      end

      context "when the post has hidden items" do
        before { create_list(:item, 2, post: post_record, hidden_at: Time.current) }

        it "shows how many next to the title, toggling the panel" do
          get root_url

          button = hidden_count.at_css("button")
          expect(button.text.strip).to eq("2 hidden")
          expect(button["data-action"]).to eq("toggle#toggle")
          expect(button["aria-controls"]).to eq(hidden_panel["id"])
        end

        it "renders the panel closed, with a lazily loaded frame for the hidden images" do
          get root_url

          expect(hidden_panel["hidden"]).not_to be_nil
          expect(hidden_panel["data-toggle-target"]).to eq("panel")
          frame = hidden_panel.at_css("turbo-frame")
          expect(frame["src"]).to eq(post_hidden_items_path(post_record))
          expect(frame["loading"]).to eq("lazy")
        end
      end
    end

    it "lists posts newest first" do
      newer_post = create(:post, title: "Wedding photos", created_at: 1.minute.from_now)

      get root_url

      expect(response.body.index(newer_post.title)).to be < response.body.index(post_record.title)
    end

    it "lists all posts with their titles" do
      other_post = create(:post, title: "Wedding photos")

      get root_url

      expect(response).to be_successful
      expect(response.body).to include(post_record.title, other_post.title)
    end

    context "when items have images" do
      let!(:item) { create(:item, post: post_record, url: "https://example.com/original.jpg").tap { |i| attach_image(i) } }

      it "renders each image linking to its preview in the modal frame" do
        get root_url

        link = Nokogiri::HTML(response.body).at_css("##{ActionView::RecordIdentifier.dom_id(item, :image)}")
        expect(link["href"]).to eq(item_path(item))
        expect(link["data-turbo-frame"]).to eq("modal")
        expect(link.at_css("img")).to be_present
      end

      it "renders a hide (×) button in the image tile's top-right corner" do
        get root_url

        tile = Nokogiri::HTML(response.body).at_css("##{ActionView::RecordIdentifier.dom_id(item, :tile)}")
        expect(tile["data-controller"]).to eq("removal")
        expect(tile["data-removal-style-value"]).to eq("shrink")

        form = tile.at_css("form[action='#{hide_item_path(item)}']")
        expect(form["class"]).to include("absolute", "top-0", "right-0")
        expect(form.at_css("input[name='_method']")["value"]).to eq("patch")
        expect(form.at_css("button")["aria-label"]).to eq("Hide image")
        expect(form.at_css("button")["class"]).to include("opacity-0", "group-hover:opacity-100")
      end
    end

    context "when items have no images" do
      let!(:item) { create(:item, post: post_record) }

      it "does not render an image tile for them" do
        get root_url

        expect(response.body).not_to include(ActionView::RecordIdentifier.dom_id(item, :tile))
      end
    end

    context "when an item is hidden" do
      let!(:item) { create(:item, post: post_record, hidden_at: Time.current).tap { |i| attach_image(i) } }

      it "does not render its image" do
        get root_url

        expect(response.body).not_to include(ActionView::RecordIdentifier.dom_id(item, :tile))
      end
    end

    describe "drag-to-reorder" do
      it "wires the image grid to the sortable controller" do
        get root_url

        grid = Nokogiri::HTML(response.body).at_css("##{ActionView::RecordIdentifier.dom_id(post_record, :grid)}")
        expect(grid["data-controller"]).to eq("sortable")
        expect(grid["data-sortable-url-value"]).to eq(post_item_order_path(post_record))
      end

      it "marks image tiles as sortable by item id, but not the Add More tile" do
        item = create(:item, post: post_record).tap { |i| attach_image(i) }

        get root_url

        page = Nokogiri::HTML(response.body)
        expect(page.at_css("##{ActionView::RecordIdentifier.dom_id(item, :tile)}")["data-sortable-id"]).to eq(item.id.to_s)
        expect(page.at_css("##{ActionView::RecordIdentifier.dom_id(post_record, :add_more)}")["data-sortable-id"]).to be_nil
      end

      it "shows images in their saved order" do
        first, second = create_list(:item, 2, post: post_record).each { |i| attach_image(i) }
        post_record.reorder_items!([ second.id, first.id ])

        get root_url

        tile_ids = Nokogiri::HTML(response.body).css("[id^='tile_item_']").map { |tile| tile["id"] }
        expect(tile_ids).to eq([ second, first ].map { |i| ActionView::RecordIdentifier.dom_id(i, :tile) })
      end
    end

    describe "the Add More tile" do
      def add_more_tile
        Nokogiri::HTML(response.body).at_css("##{ActionView::RecordIdentifier.dom_id(post_record, :add_more)}")
      end

      it "is the last tile in the post's grid" do
        create(:item, post: post_record).tap { |i| attach_image(i) }

        get root_url

        expect(add_more_tile.parent.element_children.last["id"]).to eq(add_more_tile["id"])
      end

      it "posts to collect more pins for the post" do
        get root_url

        form = add_more_tile.at_css("form[action='#{post_pins_path(post_record)}']")
        expect(form["method"]).to eq("post")
        button = form.at_css("button")
        expect(button["aria-label"]).to eq("Add more images")
        expect(button.at_css("svg")).to be_present
        expect(button.text.strip).to be_empty
      end

      context "while pins are being collected" do
        before { post_record.update!(pins_requested_at: Time.current) }

        it "shows the loading spinner instead of the button" do
          get root_url

          expect(add_more_tile.at_css("button")).to be_nil
          expect(add_more_tile.at_css("[role='status']")["aria-label"]).to eq("Loading more images")
        end
      end

      context "when the source has no more pages" do
        before { post_record.update!(search_cursor: Post::END_CURSOR) }

        it "shows No more instead of a button" do
          get root_url

          expect(add_more_tile.at_css("button")).to be_nil
          expect(add_more_tile.text.strip).to eq("No more")
        end
      end
    end
  end

  describe "removed pages" do
    let(:post_record) { create(:post) }

    { "new" => "/posts/new", "show" => "/posts/:id", "edit" => "/posts/:id/edit" }.each do |page, path|
      it "has no #{page} page" do
        get path.sub(":id", post_record.id.to_s)
        expect(response).to have_http_status(:not_found)
      end
    end

    it "has no JSON list" do
      get posts_url(format: :json)
      expect(response).to have_http_status(:not_acceptable)
    end

    it "does not allow updating a post" do
      patch "/posts/#{post_record.id}", params: { post: { title: "Updated title" } }

      expect(response).to have_http_status(:not_found)
      expect(post_record.reload.title).not_to eq("Updated title")
    end
  end

  describe "POST /create" do
    context "with valid parameters" do
      it "creates a new Post" do
        expect { post posts_url, params: { post: valid_attributes } }.to change(Post, :count).by(1)
      end

      it "redirects to the posts list" do
        post posts_url, params: { post: valid_attributes }
        expect(response).to redirect_to(root_url)
      end

      it "starts collecting pins for the post" do
        post posts_url, params: { post: valid_attributes }
        expect(CollectPinsJob).to have_been_enqueued.with(Post.last)
      end

      it "searches Pinterest by default" do
        post posts_url, params: { post: valid_attributes }
        expect(Post.last).to be_pinterest
      end

      it "searches the chosen source" do
        post posts_url, params: { post: valid_attributes.merge(source: "flickr") }

        expect(Post.last).to be_flickr
        expect(flash[:notice]).to include("Collecting images from Flickr")
      end
    end

    context "with an unknown source" do
      it "does not create a new Post" do
        expect { post posts_url, params: { post: valid_attributes.merge(source: "instagram") } }.not_to change(Post, :count)
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "with invalid parameters" do
      it "does not create a new Post" do
        expect { post posts_url, params: { post: invalid_attributes } }.not_to change(Post, :count)
      end

      it "re-renders the posts list with the error" do
        create(:post, title: "Existing post")

        post posts_url, params: { post: invalid_attributes }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Existing post", "Title can&#39;t be blank")
      end

      it "does not collect pins" do
        post posts_url, params: { post: invalid_attributes }
        expect(CollectPinsJob).not_to have_been_enqueued
      end
    end

    context "as a Turbo Stream (the idea input)" do
      let(:headers) { { "Accept" => "text/vnd.turbo-stream.html, text/html" } }

      context "with a title" do
        it "creates the post and starts collecting pins" do
          expect { post posts_url, params: { post: valid_attributes }, headers: }.to change(Post, :count).by(1)
          expect(CollectPinsJob).to have_been_enqueued.with(Post.last)
        end

        it "prepends the post to the list and resets the input" do
          post(posts_url, params: { post: valid_attributes }, headers:)

          expect(response.media_type).to eq("text/vnd.turbo-stream.html")
          streams = Nokogiri::HTML(response.body).css("turbo-stream")
          expect(streams.map { |stream| [ stream["action"], stream["target"] ] }).to eq([ %w[replace idea_form], %w[prepend posts] ])
          expect(streams.first.at_css("template input[name='post[title]']")["value"]).to be_nil
          expect(streams.last.inner_html).to include("My post")
        end

        it "keeps the chosen source selected in the reset input" do
          post(posts_url, params: { post: valid_attributes.merge(source: "flickr") }, headers:)

          form = Nokogiri::HTML(response.body).at_css("turbo-stream[target=idea_form] template")
          expect(form.at_css("input[name='post[source]'][checked]")["value"]).to eq("flickr")
        end
      end

      context "with a blank title" do
        it "does not create a post" do
          expect { post posts_url, params: { post: invalid_attributes }, headers: }.not_to change(Post, :count)
        end

        it "re-renders the input with the error" do
          post(posts_url, params: { post: invalid_attributes }, headers:)

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include('action="replace" target="idea_form"', "Title can&#39;t be blank")
        end
      end
    end
  end

  describe "DELETE /destroy" do
    let!(:post_record) { create(:post) }

    it "destroys the requested post and its items" do
      create(:item, post: post_record)

      expect { delete post_url(post_record) }
        .to change(Post, :count).by(-1)
        .and change(Item, :count).by(-1)
    end

    it "redirects to the posts list" do
      delete post_url(post_record)
      expect(response).to redirect_to(root_url)
    end

    context "as a Turbo Stream (the × button)" do
      let(:headers) { { "Accept" => "text/vnd.turbo-stream.html, text/html" } }

      it "destroys the post" do
        expect { delete(post_url(post_record), headers:) }.to change(Post, :count).by(-1)
      end

      it "removes only the post's entry from the page" do
        delete(post_url(post_record), headers:)

        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        streams = Nokogiri::HTML(response.body).css("turbo-stream")
        expect(streams.map { |stream| [ stream["action"], stream["target"] ] })
          .to eq([ [ "remove", ActionView::RecordIdentifier.dom_id(post_record, :entry) ] ])
      end
    end
  end
end
