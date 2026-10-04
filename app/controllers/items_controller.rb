class ItemsController < ApplicationController
  # DELETE /items/1 or /items/1.json
  def destroy
    @item = Item.find(params.expect(:id))
    @item.destroy!

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to root_path, notice: "Item was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end
end
