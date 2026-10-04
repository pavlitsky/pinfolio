class Posts::HiddenItemsController < ApplicationController
  # GET /posts/1/hidden_items (loaded lazily into the post's hidden images panel)
  def index
    @post = Post.find(params.expect(:post_id))
    @items = @post.items.hidden.with_attached_image.reorder(:hidden_at)
  end
end
