class AddHiddenAtAndUniqueUrlToItems < ActiveRecord::Migration[8.1]
  def change
    add_column :items, :hidden_at, :datetime
    add_index :items, %i[post_id url], unique: true
    # Covered by the composite index above
    remove_index :items, :post_id
  end
end
