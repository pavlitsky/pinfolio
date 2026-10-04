class AddPinsRequestedAtToPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :posts, :pins_requested_at, :datetime
  end
end
