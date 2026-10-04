class AddPositionToItems < ActiveRecord::Migration[8.1]
  def up
    add_column :items, :position, :integer
    # Keep the current (creation) order
    execute "UPDATE items SET position = id"
    change_column_null :items, :position, false
    add_index :items, %i[post_id position]
  end

  def down
    remove_index :items, %i[post_id position]
    remove_column :items, :position
  end
end
