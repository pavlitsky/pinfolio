require "rails_helper"

RSpec.describe "/posts/:post_id/hidden_items", type: :request do
  include ActionView::RecordIdentifier

  let!(:post_record) { create(:post) }

  def attach_image(item) = item.image.attach(io: StringIO.new("fake image"), filename: "photo.jpg", content_type: "image/jpeg")

  describe "GET /index" do
    def frame = Nokogiri::HTML(response.body).at_css("turbo-frame##{dom_id(post_record, :hidden_items)}")

    it "renders the post's hidden images panel frame" do
      get post_hidden_items_url(post_record)

      expect(response).to be_successful
      expect(frame).to be_present
    end

    context "with hidden and visible items" do
      let!(:visible) { create(:item, post: post_record).tap { |i| attach_image(i) } }
      let!(:hidden_later) { create(:item, post: post_record, hidden_at: 1.minute.ago).tap { |i| attach_image(i) } }
      let!(:hidden_earlier) { create(:item, post: post_record, hidden_at: 1.hour.ago).tap { |i| attach_image(i) } }
      let!(:other_post_hidden) { create(:item, hidden_at: Time.current).tap { |i| attach_image(i) } }

      it "shows the resized tile variant rather than the original" do
        get post_hidden_items_url(post_record)

        expect(frame.at_css("##{dom_id(hidden_later, :hidden_tile)} img")["src"]).to start_with("/rails/active_storage/representations/")
      end

      it "lists only this post's hidden items, in the order they were hidden" do
        get post_hidden_items_url(post_record)

        tile_ids = frame.css("[id^='hidden_tile_item_']").map { |tile| tile["id"] }
        expect(tile_ids).to eq([ dom_id(hidden_earlier, :hidden_tile), dom_id(hidden_later, :hidden_tile) ])
      end

      it "offers a Restore button for each" do
        get post_hidden_items_url(post_record)

        tile = frame.at_css("##{dom_id(hidden_later, :hidden_tile)}")
        form = tile.at_css("form[action='#{unhide_item_path(hidden_later)}']")
        expect(form.at_css("input[name='_method']")["value"]).to eq("patch")
        expect(form.at_css("button").text.strip).to eq("Restore")
      end
    end

    context "with no hidden items" do
      it "shows the empty message" do
        get post_hidden_items_url(post_record)

        expect(frame.at_css("##{dom_id(post_record, :hidden_grid)} p").text.strip).to eq("No hidden images.")
      end
    end

    context "when the post does not exist" do
      it "responds with not found" do
        get post_hidden_items_url(post_id: 0)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
