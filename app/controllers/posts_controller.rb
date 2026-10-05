class PostsController < ApplicationController
  # GET /posts
  def index
    @post = Post.new
    load_posts
  end

  # POST /posts
  def create
    @post = Post.new(post_params)

    respond_to do |format|
      if @post.save
        @post.collect_pins_later
        format.turbo_stream
        format.html { redirect_to root_path, notice: "Post was successfully created. Collecting images from #{@post.source_name}…" }
      else
        format.turbo_stream { render turbo_stream: turbo_stream.replace("idea_form", partial: "posts/idea_form", locals: { post: @post }), status: :unprocessable_content }
        format.html do
          load_posts
          render :index, status: :unprocessable_content
        end
      end
    end
  end

  # DELETE /posts/1
  def destroy
    @post = Post.find(params.expect(:id))
    @post.destroy!

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to root_path, notice: "Post was successfully destroyed.", status: :see_other }
    end
  end

  private
    def load_posts
      @posts = Post.includes(items: { image_attachment: :blob }).order(created_at: :desc)
    end

    # Only allow a list of trusted parameters through.
    def post_params
      params.expect(post: [ :title, :source ])
    end
end
