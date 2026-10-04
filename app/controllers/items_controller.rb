class ItemsController < ApplicationController
  before_action :set_item

  # GET /items/1 (rendered into the "modal" frame as an image preview)
  def show
    # Opened outside the preview (new tab, no JavaScript): go straight to the pin
    return redirect_to(@item.url, allow_other_host: true) unless turbo_frame_request?

    ids = @post.gallery_item_ids
    @position = ids.index(@item.id)
    @total = ids.size
    @previous_id = ids[@position - 1] if @position&.positive?
    @next_id = ids[@position + 1] if @position
  end

  # PATCH /items/1/hide
  def hide
    @item.hide!

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to root_path, notice: "Image was hidden.", status: :see_other }
    end
  end

  # PATCH /items/1/unhide
  def unhide
    @item.unhide!

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to root_path, notice: "Image was restored.", status: :see_other }
    end
  end

  private
    def set_item
      @item = Item.find(params.expect(:id))
      @post = @item.post
    end
end
