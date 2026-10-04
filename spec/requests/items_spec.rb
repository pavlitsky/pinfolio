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
  end

  describe "DELETE /destroy" do
    let!(:item) { create(:item) }

    it "destroys the requested item" do
      expect { delete item_url(item) }.to change(Item, :count).by(-1)
    end

    it "redirects to the posts list" do
      delete item_url(item)
      expect(response).to redirect_to(root_url)
    end

    context "as a Turbo Stream (the × on an image)" do
      let(:headers) { { "Accept" => "text/vnd.turbo-stream.html, text/html" } }

      it "destroys the item" do
        expect { delete(item_url(item), headers:) }.to change(Item, :count).by(-1)
      end

      it "removes only the item's image tile" do
        delete(item_url(item), headers:)

        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        streams = Nokogiri::HTML(response.body).css("turbo-stream")
        expect(streams.map { |stream| [ stream["action"], stream["target"] ] })
          .to eq([ [ "remove", ActionView::RecordIdentifier.dom_id(item, :tile) ] ])
      end
    end
  end
end
