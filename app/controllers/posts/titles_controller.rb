class Posts::TitlesController < ApplicationController
  before_action :set_post

  # GET /posts/1/title (the title, rendered into its turbo frame)
  def show
  end

  # GET /posts/1/title/edit (the inline form, rendered into the same frame)
  def edit
  end

  # PATCH /posts/1/title
  def update
    if @post.update(title_params)
      redirect_to post_title_path(@post), status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_post
      @post = Post.find(params.expect(:post_id))
    end

    def title_params
      params.expect(post: [ :title ])
    end
end
