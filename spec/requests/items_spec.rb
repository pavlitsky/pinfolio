require "rails_helper"

RSpec.describe "/items", type: :request do
  include ActionView::RecordIdentifier

  describe "removed pages" do
    let!(:item) { create(:item) }

    { "index" => "/items", "new" => "/items/new", "edit" => "/items/:id/edit" }.each do |page, path|
      it "has no #{page} page" do
        get path.sub(":id", item.id.to_s)
        expect(response).to have_http_status(:not_found)
      end
    end

    it "does not allow creating an item" do
      expect { post "/items", params: { item: { post_id: item.post_id, url: "https://example.com/image.jpg" } } }
        .not_to change(Item, :count)
      expect(response).to have_http_status(:not_found)
    end

    it "does not allow updating an item" do
      patch "/items/#{item.id}", params: { item: { url: "https://example.com/new.jpg" } }

      expect(response).to have_http_status(:not_found)
      expect(item.reload.url).not_to eq("https://example.com/new.jpg")
    end

    it "does not allow deleting an item" do
      expect { delete "/items/#{item.id}" }.not_to change(Item, :count)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /show (image preview)" do
    def attach_image(item) = item.image.attach(io: StringIO.new("fake image"), filename: "photo.jpg", content_type: "image/jpeg")

    let(:post_record) { create(:post, title: "Cozy cabin") }
    let!(:items) { create_list(:item, 3, post: post_record).each { |item| attach_image(item) } }
    let(:frame_headers) { { "Turbo-Frame" => "modal" } }

    def frame = Nokogiri::HTML(response.body).at_css("turbo-frame#modal")
    def previous_link = frame.at_css("a[data-modal-target='previous']")
    def next_link = frame.at_css("a[data-modal-target='next']")

    context "when opened in the modal frame" do
      it "renders the large image linking to the pin in a new tab" do
        get(item_url(items[1]), headers: frame_headers)

        link = frame.css("a[href='#{items[1].url}']").find { |a| a.at_css("img") }
        expect(link["target"]).to eq("_blank")
        expect(link.at_css("img")["src"]).to start_with("/rails/active_storage/")
      end

      it "names the post's source in the links to the original" do
        get(item_url(items[1]), headers: frame_headers)
        expect(frame.text).to include("Open on Pinterest")

        post_record.update!(source: :flickr)
        get(item_url(items[1]), headers: frame_headers)
        expect(frame.text).to include("Open on Flickr")
      end

      it "shows the resized preview variant rather than the original" do
        get(item_url(items[1]), headers: frame_headers)

        expect(frame.at_css("img")["src"]).to start_with("/rails/active_storage/representations/")
      end

      it "shows the post title and position" do
        get(item_url(items[1]), headers: frame_headers)

        expect(frame.text).to include("Cozy cabin", "2 of 3")
      end

      it "links to the previous and next images" do
        get(item_url(items[1]), headers: frame_headers)

        expect(previous_link["href"]).to eq(item_path(items[0]))
        expect(next_link["href"]).to eq(item_path(items[2]))
      end

      it "has no previous link on the first image" do
        get(item_url(items[0]), headers: frame_headers)

        expect(previous_link).to be_nil
        expect(next_link["href"]).to eq(item_path(items[1]))
      end

      it "has no next link on the last image" do
        get(item_url(items[2]), headers: frame_headers)

        expect(next_link).to be_nil
      end

      it "skips hidden items and items without images" do
        items[1].hide!
        create(:item, post: post_record)

        get(item_url(items[0]), headers: frame_headers)

        expect(next_link["href"]).to eq(item_path(items[2]))
        expect(frame.text).to include("1 of 2")
      end

      it "offers Hide, advancing the preview once it succeeds" do
        get(item_url(items[1]), headers: frame_headers)

        form = frame.at_css("form[action='#{hide_item_path(items[1])}']")
        expect(form["data-action"]).to eq("turbo:submit-end->modal#advance")
        expect(form.at_css("input[name='_method']")["value"]).to eq("patch")
      end
    end

    context "when opened outside the preview (new tab or no JavaScript)" do
      it "redirects to the pin" do
        get item_url(items[1])
        expect(response).to redirect_to(items[1].url)
      end
    end
  end

  describe "PATCH /hide" do
    let!(:item) { create(:item) }
    let(:post_record) { item.post }

    it "hides the item without deleting it" do
      expect { patch hide_item_url(item) }.not_to change(Item, :count)
      expect(item.reload).to be_hidden
    end

    it "redirects to the posts list" do
      patch hide_item_url(item)
      expect(response).to redirect_to(root_url)
    end

    context "as a Turbo Stream (the × on an image)" do
      let(:headers) { { "Accept" => "text/vnd.turbo-stream.html, text/html" } }

      def streams = Nokogiri::HTML(response.body).css("turbo-stream")
      def stream_for(target) = streams.find { |stream| stream["target"] == target }

      it "removes the tile, adds it to the hidden panel, updates the count and shows an Undo toast" do
        patch(hide_item_url(item), headers:)

        expect(item.reload).to be_hidden
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(streams.map { |stream| [ stream["action"], stream["target"] ] }).to eq([
          [ "remove", dom_id(item, :tile) ],
          [ "append", dom_id(post_record, :hidden_grid) ],
          [ "replace", dom_id(post_record, :hidden_count) ],
          [ "append", "toasts" ]
        ])
      end

      it "renders the hidden tile with a Restore button" do
        patch(hide_item_url(item), headers:)

        tile = stream_for(dom_id(post_record, :hidden_grid)).at_css("template ##{dom_id(item, :hidden_tile)}")
        expect(tile.at_css("form[action='#{unhide_item_path(item)}'] button").text.strip).to eq("Restore")
      end

      it "updates the hidden count" do
        patch(hide_item_url(item), headers:)

        expect(stream_for(dom_id(post_record, :hidden_count)).at_css("template button").text.strip).to eq("1 hidden")
      end

      it "shows a self-dismissing toast with an Undo button" do
        patch(hide_item_url(item), headers:)

        toast = stream_for("toasts").at_css("template ##{dom_id(item, :toast)}")
        expect(toast["data-controller"]).to eq("toast removal")
        expect(toast.text).to include("Image hidden")
        expect(toast.at_css("form[action='#{unhide_item_path(item)}'] button").text.strip).to eq("Undo")
      end
    end
  end

  describe "PATCH /unhide" do
    let!(:item) { create(:item, hidden_at: Time.current) }
    let(:post_record) { item.post }

    it "makes the item visible again" do
      patch unhide_item_url(item)
      expect(item.reload).not_to be_hidden
    end

    it "redirects to the posts list" do
      patch unhide_item_url(item)
      expect(response).to redirect_to(root_url)
    end

    context "as a Turbo Stream (Undo or Restore)" do
      let(:headers) { { "Accept" => "text/vnd.turbo-stream.html, text/html" } }

      def streams = Nokogiri::HTML(response.body).css("turbo-stream")

      def attach_image(item) = item.image.attach(io: StringIO.new("fake image"), filename: "photo.jpg", content_type: "image/jpeg")

      before { attach_image(item) }

      it "removes the toast and hidden tile, re-renders the grid and updates the count" do
        patch(unhide_item_url(item), headers:)

        expect(streams.map { |stream| [ stream["action"], stream["target"] ] }).to eq([
          [ "remove", dom_id(item, :toast) ],
          [ "remove", dom_id(item, :hidden_tile) ],
          [ "replace", dom_id(post_record, :grid) ],
          [ "replace", dom_id(post_record, :hidden_count) ]
        ])
      end

      it "puts the image back in its original position in the grid" do
        first, middle, last = create_list(:item, 3, post: create(:post)).each { |i| attach_image(i) }
        middle.hide!

        patch(unhide_item_url(middle), headers:)

        grid = streams.find { |stream| stream["target"] == dom_id(middle.post, :grid) }
        tile_ids = grid.css("template [id^='tile_item_']").map { |tile| tile["id"] }
        expect(tile_ids).to eq([ first, middle, last ].map { |i| dom_id(i, :tile) })
      end

      it "leaves no hidden count once nothing is hidden" do
        patch(unhide_item_url(item), headers:)

        count = streams.find { |stream| stream["target"] == dom_id(post_record, :hidden_count) }
        expect(count.at_css("template button")).to be_nil
      end
    end
  end
end
