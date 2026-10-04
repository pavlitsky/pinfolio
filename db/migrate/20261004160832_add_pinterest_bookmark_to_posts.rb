class AddPinterestBookmarkToPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :posts, :pinterest_bookmark, :text
  end
end
