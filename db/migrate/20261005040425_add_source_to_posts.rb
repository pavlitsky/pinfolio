class AddSourceToPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :posts, :source, :string, null: false, default: "pinterest"
    add_check_constraint :posts, "source IN ('pinterest', 'flickr')", name: "posts_source_check"
    rename_column :posts, :pinterest_bookmark, :search_cursor
  end
end
