class CreateItems < ActiveRecord::Migration[8.1]
  def change
    create_table :items do |t|
      t.references :post, null: false, foreign_key: true
      t.string :url, null: false

      t.timestamps
    end
  end
end
