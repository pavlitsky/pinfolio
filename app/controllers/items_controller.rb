class ItemsController < ApplicationController
  before_action :set_item

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
