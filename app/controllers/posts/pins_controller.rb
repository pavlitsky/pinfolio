class Posts::PinsController < ApplicationController
  # POST /posts/1/pins
  def create
    @post = Post.find(params.expect(:post_id))
    @post.collect_pins_later

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to root_path, notice: "Collecting more images from Pinterest…", status: :see_other }
    end
  end
end
