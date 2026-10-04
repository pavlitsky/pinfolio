class ItemsController < ApplicationController
  # PATCH /items/1/hide
  def hide
    @item = Item.find(params.expect(:id))
    @item.hide!

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to root_path, notice: "Image was hidden.", status: :see_other }
    end
  end
end
