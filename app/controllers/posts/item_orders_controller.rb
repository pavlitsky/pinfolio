class Posts::ItemOrdersController < ApplicationController
  # PATCH /posts/1/item_order (item_ids in their new order, sent after a drag)
  def update
    post = Post.find(params.expect(:post_id))
    post.reorder_items!(params.expect(item_ids: []))

    head :no_content
  end
end
