require "rails_helper"

RSpec.describe "/items", type: :request do
  let(:post_record) { create(:post) }
  let(:valid_attributes) { { post_id: post_record.id, url: "https://example.com/image.jpg" } }
  let(:invalid_attributes) { { post_id: post_record.id, url: "" } }

  describe "GET /index" do
    it "renders a successful response" do
      create(:item)
      get items_url
      expect(response).to be_successful
    end
  end

  describe "GET /show" do
    it "renders a successful response" do
      get item_url(create(:item))
      expect(response).to be_successful
    end

    context "as JSON" do
      it "returns the item's url and a null image_url when no image is attached" do
        item = create(:item)

        get item_url(item, format: :json)

        expect(response.parsed_body).to include("url" => item.url, "post_id" => item.post_id, "image_url" => nil)
      end

      it "returns the image_url when an image is attached" do
        item = create(:item)
        item.image.attach(io: StringIO.new("fake image"), filename: "image.jpg", content_type: "image/jpeg")

        get item_url(item, format: :json)

        expect(response.parsed_body["image_url"]).to include("image.jpg")
      end
    end
  end

  describe "GET /new" do
    it "renders a successful response" do
      get new_item_url
      expect(response).to be_successful
    end
  end

  describe "GET /edit" do
    it "renders a successful response" do
      get edit_item_url(create(:item))
      expect(response).to be_successful
    end
  end

  describe "POST /create" do
    context "with valid parameters" do
      it "creates a new Item" do
        expect { post items_url, params: { item: valid_attributes } }.to change(Item, :count).by(1)
      end

      it "redirects to the created item" do
        post items_url, params: { item: valid_attributes }
        expect(response).to redirect_to(item_url(Item.last))
      end
    end

    context "with invalid parameters" do
      it "does not create a new Item" do
        expect { post items_url, params: { item: invalid_attributes } }.not_to change(Item, :count)
      end

      it "renders a response with 422 status" do
        post items_url, params: { item: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "without a post" do
      it "does not create a new Item" do
        expect { post items_url, params: { item: { url: "https://example.com/image.jpg" } } }.not_to change(Item, :count)
      end
    end
  end

  describe "PATCH /update" do
    let!(:item) { create(:item) }

    context "with valid parameters" do
      it "updates the requested item" do
        patch item_url(item), params: { item: { url: "https://example.com/new.jpg" } }
        expect(item.reload.url).to eq("https://example.com/new.jpg")
      end

      it "redirects to the item" do
        patch item_url(item), params: { item: { url: "https://example.com/new.jpg" } }
        expect(response).to redirect_to(item_url(item))
      end
    end

    context "with invalid parameters" do
      it "renders a response with 422 status" do
        patch item_url(item), params: { item: { url: "not-a-url" } }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "DELETE /destroy" do
    let!(:item) { create(:item) }

    it "destroys the requested item" do
      expect { delete item_url(item) }.to change(Item, :count).by(-1)
    end

    it "redirects to the items list" do
      delete item_url(item)
      expect(response).to redirect_to(items_url)
    end
  end
end
