require "rails_helper"

RSpec.describe "/items", type: :request do
  describe "removed pages" do
    let!(:item) { create(:item) }

    { "index" => "/items", "new" => "/items/new", "show" => "/items/:id", "edit" => "/items/:id/edit" }.each do |page, path|
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

  describe "PATCH /hide" do
    let!(:item) { create(:item) }

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

      it "removes only the item's image tile" do
        patch(hide_item_url(item), headers:)

        expect(item.reload).to be_hidden
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        streams = Nokogiri::HTML(response.body).css("turbo-stream")
        expect(streams.map { |stream| [ stream["action"], stream["target"] ] })
          .to eq([ [ "remove", ActionView::RecordIdentifier.dom_id(item, :tile) ] ])
      end
    end
  end
end
