require "rails_helper"

RSpec.describe "/posts/:post_id/item_order", type: :request do
  let(:post_record) { create(:post) }
  let!(:items) { create_list(:item, 3, post: post_record) }

  describe "PATCH /update" do
    it "saves the new order of the post's items" do
      patch post_item_order_url(post_record), params: { item_ids: items.reverse.map(&:id) }

      expect(response).to have_http_status(:no_content)
      expect(post_record.reload.items).to eq(items.reverse)
    end

    it "does not move other posts' items" do
      other_item = create(:item)

      expect { patch post_item_order_url(post_record), params: { item_ids: [ other_item.id, items.first.id ] } }
        .not_to change { other_item.reload.position }
    end

    context "without item ids" do
      it "responds with bad request" do
        patch post_item_order_url(post_record)
        expect(response).to have_http_status(:bad_request)
      end
    end

    context "when the post does not exist" do
      it "responds with not found" do
        patch post_item_order_url(post_id: 0), params: { item_ids: [ items.first.id ] }
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
